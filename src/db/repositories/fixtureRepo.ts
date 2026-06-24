import { db } from '../database';
import { now, type FixtureId } from '@/models/common';
import type { Fixture } from '@/models/fixture';

/**
 * Data access for the global fixture library. Repositories keep Dexie calls out
 * of the UI and own the audit-stamp bookkeeping.
 */
export const fixtureRepo = {
  all(): Promise<Fixture[]> {
    return db.fixtures.orderBy('manufacturer').toArray();
  },

  get(id: FixtureId): Promise<Fixture | undefined> {
    return db.fixtures.get(id);
  },

  getMany(ids: FixtureId[]): Promise<(Fixture | undefined)[]> {
    return db.fixtures.bulkGet(ids);
  },

  byManufacturer(manufacturer: string): Promise<Fixture[]> {
    return db.fixtures.where('manufacturer').equals(manufacturer).toArray();
  },

  /** Match a console-reported type to a library entry by GDTF type id. */
  byGdtfTypeId(gdtfFixtureTypeId: string): Promise<Fixture | undefined> {
    return db.fixtures
      .where('source.gdtfFixtureTypeId')
      .equals(gdtfFixtureTypeId)
      .first();
  },

  async put(fixture: Fixture): Promise<FixtureId> {
    fixture.updatedAt = now();
    await db.fixtures.put(fixture);
    return fixture.id;
  },

  /** Bulk upsert, used by GDTF sync. */
  bulkPut(fixtures: Fixture[]): Promise<FixtureId> {
    const stamp = now();
    fixtures.forEach((f) => (f.updatedAt = stamp));
    return db.fixtures.bulkPut(fixtures) as unknown as Promise<FixtureId>;
  },

  delete(id: FixtureId): Promise<void> {
    return db.fixtures.delete(id);
  },
};
