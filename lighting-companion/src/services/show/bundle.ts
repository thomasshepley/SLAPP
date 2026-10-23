import { db } from '@/db';
import { newId, type FileId, type FixtureId, type ShowId } from '@/models/common';
import type { Fixture } from '@/models/fixture';
import type { BundledFile, Show, ShowBundle } from '@/models/show';
import type { StoredFile } from '@/models/files';

const BUNDLE_VERSION = 1;

/**
 * Portable show export/import (brief §2). A bundle is a self-contained JSON file
 * holding the show, the library fixtures its patch depends on, and any
 * referenced binary files inlined as base64 — so it transfers cleanly to
 * another device where those fixtures/files may not exist yet.
 */

// --- base64 helpers (work in browser and Node/Vitest) ---------------------

async function blobToBase64(blob: Blob): Promise<string> {
  const buf = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  for (let i = 0; i < buf.length; i++) binary += String.fromCharCode(buf[i]!);
  return typeof btoa === 'function' ? btoa(binary) : Buffer.from(buf).toString('base64');
}

function base64ToBlob(data: string, mimeType: string): Blob {
  const binary = typeof atob === 'function' ? atob(data) : Buffer.from(data, 'base64').toString('binary');
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return new Blob([bytes], { type: mimeType });
}

/** Collect every FileId referenced by a show (plot, cheat sheet). */
function referencedFileIds(show: Show): FileId[] {
  const ids: FileId[] = [];
  if (show.plot) ids.push(show.plot.pdf.fileId);
  if (show.cheatSheet) ids.push(show.cheatSheet.pdf.fileId);
  return ids;
}

export async function exportBundle(showId: ShowId): Promise<ShowBundle> {
  const show = await db.shows.get(showId);
  if (!show) throw new Error('Show not found');

  const fixtureIds = [...new Set(show.patch.map((p) => p.fixtureId))];
  const fixtures = (await db.fixtures.bulkGet(fixtureIds)).filter(
    (f): f is Fixture => f !== undefined,
  );

  const fileIds = referencedFileIds(show);
  const storedFiles = (await db.files.bulkGet(fileIds)).filter(
    (f): f is StoredFile => f !== undefined,
  );
  const files: BundledFile[] = await Promise.all(
    storedFiles.map(async (f) => ({
      fileId: f.id,
      filename: f.filename,
      mimeType: f.mimeType,
      data: await blobToBase64(f.blob),
    })),
  );

  return { bundleVersion: BUNDLE_VERSION, exportedAt: new Date().toISOString(), show, fixtures, files };
}

/** Serialize a bundle to a downloadable JSON string. */
export function bundleToJson(bundle: ShowBundle): string {
  return JSON.stringify(bundle, null, 2);
}

export function parseBundle(json: string): ShowBundle {
  const parsed = JSON.parse(json) as ShowBundle;
  if (!parsed.show || typeof parsed.bundleVersion !== 'number') {
    throw new Error('Not a valid show bundle');
  }
  return parsed;
}

/**
 * Import a bundle as a NEW show (fresh id) so it never overwrites an existing
 * one. Missing library fixtures are added; existing ids are left untouched.
 * Files are restored to the blob store under fresh ids and re-linked.
 */
export async function importBundle(bundle: ShowBundle): Promise<Show> {
  return db.transaction('rw', db.shows, db.fixtures, db.files, async () => {
    // Restore fixtures that aren't already present.
    for (const fixture of bundle.fixtures as Fixture[]) {
      const exists = await db.fixtures.get(fixture.id as FixtureId);
      if (!exists) await db.fixtures.add(fixture);
    }

    // Restore files under fresh ids, mapping old → new for re-linking.
    const idMap = new Map<string, FileId>();
    for (const bf of bundle.files) {
      const newFileId = newId<FileId>();
      idMap.set(bf.fileId, newFileId);
      const blob = base64ToBlob(bf.data, bf.mimeType);
      await db.files.add({
        id: newFileId,
        kind: 'export-pdf',
        filename: bf.filename,
        mimeType: bf.mimeType,
        byteSize: blob.size,
        blob,
        createdAt: new Date().toISOString() as never,
        updatedAt: new Date().toISOString() as never,
      });
    }

    const remap = (fileId: FileId): FileId => idMap.get(fileId) ?? fileId;
    const show: Show = {
      ...bundle.show,
      id: newId<ShowId>(),
      name: `${bundle.show.name} (imported)`,
      dirty: false,
    };
    if (show.plot) show.plot = { ...show.plot, pdf: { ...show.plot.pdf, fileId: remap(show.plot.pdf.fileId) } };
    if (show.cheatSheet) {
      show.cheatSheet = { ...show.cheatSheet, pdf: { ...show.cheatSheet.pdf, fileId: remap(show.cheatSheet.pdf.fileId) } };
    }

    await db.shows.add(show);
    return show;
  });
}
