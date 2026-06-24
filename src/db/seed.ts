import { db } from './database';
import { seedGels } from '@/data/gels';
import { seedFixtures } from '@/data/fixtures';

/**
 * Populate the library with starter gel + fixture data on first run. Idempotent:
 * seed records use deterministic ids, and we only seed an empty table, so user
 * edits and added fixtures are never clobbered on subsequent launches.
 */
export async function seedDatabase(): Promise<void> {
  await db.transaction('rw', db.gels, db.fixtures, async () => {
    if ((await db.gels.count()) === 0) {
      await db.gels.bulkAdd(seedGels());
    }
    if ((await db.fixtures.count()) === 0) {
      await db.fixtures.bulkAdd(seedFixtures());
    }
  });
}
