import type { Auditable, FileId, FixtureId } from './common';

/**
 * Binary assets (GDTF archives, manual PDFs, DMX-table PDFs, Polycam exports)
 * are stored as Blobs in their own IndexedDB table, keyed by FileId. Domain
 * records reference them by id only — they never embed the bytes — so that
 * deleting a show doesn't drag megabytes of PDF around, and the same manual
 * can be shared by every fixture that links to it.
 */

export type StoredFileKind =
  | 'gdtf' // .gdtf archive pulled from GDTF-Share
  | 'manual-pdf' // fixture user manual
  | 'dmx-table-pdf' // channel/DMX chart
  | 'polycam-pdf' // imported lighting plot
  | 'export-pdf'; // generated cheat sheet / job pack (cached)

export interface StoredFile extends Auditable {
  id: FileId;
  kind: StoredFileKind;
  /** Original filename for display / re-export. */
  filename: string;
  mimeType: string;
  byteSize: number;
  /** The actual payload. */
  blob: Blob;
  /**
   * Optional owning fixture for library assets. Job-scoped files (Polycam,
   * exports) leave this undefined and are referenced from the Show instead.
   */
  fixtureId?: FixtureId;
  /** sha-256 hex of the blob, used to dedupe identical uploads on sync. */
  contentHash?: string;
}

/** Lightweight handle stored inside domain records (no bytes). */
export interface FileRef {
  fileId: FileId;
  filename: string;
  mimeType: string;
}
