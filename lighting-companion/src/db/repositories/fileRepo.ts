import { db } from '../database';
import { newId, now, type FileId } from '@/models/common';
import type { FileRef, StoredFile, StoredFileKind } from '@/models/files';

/** Data access for binary blobs (GDTF, PDFs). */
export const fileRepo = {
  get(id: FileId): Promise<StoredFile | undefined> {
    return db.files.get(id);
  },

  /** Resolve a domain FileRef to a runtime object URL for rendering/download. */
  async objectUrl(ref: FileRef): Promise<string | undefined> {
    const file = await db.files.get(ref.fileId);
    return file ? URL.createObjectURL(file.blob) : undefined;
  },

  async store(
    blob: Blob,
    kind: StoredFileKind,
    filename: string,
    fixtureId?: StoredFile['fixtureId'],
  ): Promise<FileRef> {
    const stamp = now();
    const file: StoredFile = {
      id: newId<FileId>(),
      kind,
      filename,
      mimeType: blob.type,
      byteSize: blob.size,
      blob,
      fixtureId,
      createdAt: stamp,
      updatedAt: stamp,
    };
    await db.files.put(file);
    return { fileId: file.id, filename, mimeType: file.mimeType };
  },

  delete(id: FileId): Promise<void> {
    return db.files.delete(id);
  },

  /** Remove files orphaned by a deleted show/fixture. */
  deleteMany(ids: FileId[]): Promise<void> {
    return db.files.bulkDelete(ids);
  },
};
