import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db';
import type { Fixture } from '@/models/fixture';
import type { Gel } from '@/models/colour';

/** Reactive list of all library fixtures, sorted by manufacturer then model. */
export function useFixtures(): Fixture[] {
  return (
    useLiveQuery(async () => {
      const all = await db.fixtures.toArray();
      return all.sort((a, b) =>
        `${a.manufacturer} ${a.model}`.localeCompare(`${b.manufacturer} ${b.model}`),
      );
    }, []) ?? []
  );
}

/** Reactive gel list, optionally filtered by a free-text query + manufacturer. */
export function useGels(query = '', manufacturer = 'all'): Gel[] {
  return (
    useLiveQuery(async () => {
      let gels = await db.gels.toArray();
      if (manufacturer !== 'all') {
        gels = gels.filter((g) => g.manufacturer === manufacturer);
      }
      const q = query.trim().toLowerCase();
      if (q) {
        gels = gels.filter((g) =>
          `${g.manufacturer} ${g.number} ${g.name} ${g.description ?? ''}`
            .toLowerCase()
            .includes(q),
        );
      }
      return gels.sort((a, b) => a.number.localeCompare(b.number, undefined, { numeric: true }));
    }, [query, manufacturer]) ?? []
  );
}
