import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db';
import type { Show } from '@/models/show';

/** Reactive list of saved shows, newest first. */
export function useShows(): Show[] {
  return (
    useLiveQuery(async () => {
      const all = await db.shows.toArray();
      return all.sort((a, b) => (a.updatedAt < b.updatedAt ? 1 : -1));
    }, []) ?? []
  );
}
