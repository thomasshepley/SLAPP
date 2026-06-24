import type { Auditable, ShowId, Versioned } from './common';
import type { ConsoleConfig } from './console';
import type { FileRef } from './files';
import type { PatchItem, UniverseProfile } from './patch';
import type { PolycamPlot } from './plot';
import type { PowerBudget } from './power';

/**
 * A Show is the per-job aggregate. The brief's "Show Management" (s2) and "Job
 * Management" (s12) are the same record viewed two ways: a Show *is* a saved
 * job. It owns everything job-scoped; the fixture library it points into is
 * global. This is the unit that is saved, opened, duplicated, exported as a
 * JSON bundle, and partially imported-from by the cross-show import tool.
 */
export interface Show extends Auditable, Versioned {
  id: ShowId;
  name: string;
  notes?: string;

  console: ConsoleConfig;
  universeProfile: UniverseProfile;
  patch: PatchItem[];

  plot?: PolycamPlot;
  powerBudget?: PowerBudget;

  /** Most recently generated cheat sheet / job pack, cached for re-share. */
  cheatSheet?: GeneratedDocument;

  /** Set when the user has unsaved changes pending an explicit/auto save. */
  dirty?: boolean;
}

export interface GeneratedDocument {
  kind: 'cheat-sheet' | 'job-pack';
  generatedAt: string;
  pdf: FileRef;
}

/**
 * Portable export bundle (s2 "Export show as a portable file"). Embeds the
 * referenced binary files inline (base64) so the bundle is self-contained for
 * transfer to another device, unlike the on-device FileRef indirection.
 */
export interface ShowBundle {
  bundleVersion: number;
  exportedAt: string;
  show: Show;
  /** Library fixtures the patch depends on, so the import resolves cleanly. */
  fixtures: unknown[]; // Fixture[] — kept loose to avoid an import cycle here
  /** Inlined file payloads keyed by FileId. */
  files: BundledFile[];
}

export interface BundledFile {
  fileId: string;
  filename: string;
  mimeType: string;
  /** base64-encoded blob bytes. */
  data: string;
}

/** Selection passed to the cross-show import tool (s2). */
export interface CrossShowImportSelection {
  sourceShowId: ShowId;
  importPatch: 'all' | 'none' | { fixtureIds: string[] };
  importUniverseProfile: boolean;
  importPowerBudget: boolean;
  importNotes: boolean;
  /** How to resolve collisions with the current show's patch. */
  conflictStrategy: 'merge' | 'replace';
}
