import Dexie, { type EntityTable } from 'dexie';
import type { Fixture } from '@/models/fixture';
import type { Show } from '@/models/show';
import type { StoredFile } from '@/models/files';
import type { Gel } from '@/models/colour';
import type { AppSettings } from '@/models/settings';

/**
 * The single IndexedDB database for the whole app. Everything client-side per
 * the brief: fixture library, saved shows, binary files, gel reference and
 * settings all live here.
 *
 * Schema versioning rule: NEVER edit an existing `.version(n).stores(...)`
 * block once it has shipped. Add a new `.version(n+1)` block and an `upgrade`
 * callback for any data transform. This is exactly the discipline the brief's
 * closing note warns about — get the storage layer settled before the UI piles
 * on top of it.
 *
 * Index strings list only the indexed keys (primary key first, then secondary
 * indexes). The full record shape is whatever the typed table says; non-indexed
 * fields (blobs, nested arrays) are stored but not queryable.
 */
export class LightingCompanionDB extends Dexie {
  fixtures!: EntityTable<Fixture, 'id'>;
  shows!: EntityTable<Show, 'id'>;
  files!: EntityTable<StoredFile, 'id'>;
  gels!: EntityTable<Gel, 'id'>;
  settings!: EntityTable<AppSettings, 'id'>;

  constructor() {
    super('shepley-lighting-companion');

    this.version(1).stores({
      // Library is queried by manufacturer/model and by GDTF type on sync.
      fixtures:
        'id, manufacturer, model, category, source.gdtfFixtureTypeId, updatedAt',
      // Shows listed by name/date in the library view.
      shows: 'id, name, updatedAt, createdAt',
      // Files looked up by owning fixture and by kind for cleanup/sync.
      files: 'id, fixtureId, kind, contentHash',
      // Gels searched by manufacturer + number; name search is in-memory.
      gels: 'id, manufacturer, number, name',
      // Single settings row.
      settings: 'id',
    });
  }
}

export const db = new LightingCompanionDB();
