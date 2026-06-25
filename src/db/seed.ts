import { db } from './database';
import { seedGels } from '@/data/gels';
import { seedFixtures } from '@/data/fixtures';
import type { Fixture } from '@/models/fixture';

/**
 * Bumped whenever the curated fixture/gel seed set changes. Existing installs
 * compare this against the value they last reconciled (in localStorage) and
 * pull in any new or refreshed curated entries — without it, the library would
 * be frozen at whatever shipped the day the user first opened the app.
 */
export const CURATED_SEED_VERSION = 2;

const SEED_VERSION_KEY = 'slapp.curatedSeedVersion';

/**
 * Populate the library with starter gel + fixture data, and keep curated
 * entries in sync as the bundled set grows.
 *
 * - First run (empty tables): bulk-insert everything.
 * - Later runs: if the curated seed version advanced, upsert curated fixtures
 *   so new models appear. Entries the user has hand-edited (`userModified`) or
 *   added themselves are never touched; their `createdAt` is preserved.
 */
export async function seedDatabase(): Promise<void> {
  await db.transaction('rw', db.gels, db.fixtures, async () => {
    if ((await db.gels.count()) === 0) {
      await db.gels.bulkAdd(seedGels());
    }

    const fixtureCount = await db.fixtures.count();
    if (fixtureCount === 0) {
      await db.fixtures.bulkAdd(seedFixtures());
      return;
    }

    if (!seedVersionChanged()) return;
    await reconcileCuratedFixtures();
  });

  markSeedVersionApplied();
}

/**
 * Force a curated re-sync regardless of the stored version — used by the
 * "Restore fixture library" action in Settings. Returns how many curated
 * entries were added or refreshed.
 */
export async function restoreCuratedLibrary(): Promise<number> {
  let count = 0;
  await db.transaction('rw', db.fixtures, async () => {
    count = await reconcileCuratedFixtures();
  });
  markSeedVersionApplied();
  return count;
}

/** True when the bundled curated set is newer than what this install reconciled. */
function seedVersionChanged(): boolean {
  try {
    const stored = Number(localStorage.getItem(SEED_VERSION_KEY) ?? '0');
    return stored < CURATED_SEED_VERSION;
  } catch {
    // localStorage unavailable (private mode etc.) — reconcile to be safe.
    return true;
  }
}

function markSeedVersionApplied(): void {
  try {
    localStorage.setItem(SEED_VERSION_KEY, String(CURATED_SEED_VERSION));
  } catch {
    /* ignore — we'll just reconcile again next launch */
  }
}

/**
 * Add new curated fixtures and refresh unmodified ones, leaving user-owned
 * records (manual additions and hand-edited curated entries) intact.
 */
async function reconcileCuratedFixtures(): Promise<number> {
  const incoming = seedFixtures();
  const existing = await db.fixtures.bulkGet(incoming.map((f) => f.id));

  const toPut: Fixture[] = [];
  incoming.forEach((fixture, i) => {
    const current = existing[i];
    if (!current) {
      toPut.push(fixture); // brand-new curated model
    } else if (!current.userModified) {
      // Refresh curated data but keep the original creation timestamp.
      toPut.push({ ...fixture, createdAt: current.createdAt });
    }
    // else: user-edited this entry — leave it alone.
  });

  if (toPut.length > 0) await db.fixtures.bulkPut(toPut);
  return toPut.length;
}
