import { db } from '../database';
import { newId, now, type ShowId } from '@/models/common';
import type { Show } from '@/models/show';

const SHOW_SCHEMA_VERSION = 1;

/** Data access for saved shows / jobs. */
export const showRepo = {
  list(): Promise<Show[]> {
    return db.shows.orderBy('updatedAt').reverse().toArray();
  },

  get(id: ShowId): Promise<Show | undefined> {
    return db.shows.get(id);
  },

  async create(partial: Omit<Show, 'id' | 'createdAt' | 'updatedAt' | 'schemaVersion'>): Promise<Show> {
    const stamp = now();
    const show: Show = {
      ...partial,
      id: newId<ShowId>(),
      schemaVersion: SHOW_SCHEMA_VERSION,
      createdAt: stamp,
      updatedAt: stamp,
    };
    await db.shows.put(show);
    return show;
  },

  async save(show: Show): Promise<ShowId> {
    show.updatedAt = now();
    show.dirty = false;
    await db.shows.put(show);
    return show.id;
  },

  /** Duplicate a show as a starting point for a similar job (s2). */
  async duplicate(id: ShowId, newName: string): Promise<Show | undefined> {
    const source = await db.shows.get(id);
    if (!source) return undefined;
    const stamp = now();
    const copy: Show = {
      ...structuredClone(source),
      id: newId<ShowId>(),
      name: newName,
      createdAt: stamp,
      updatedAt: stamp,
      dirty: false,
    };
    await db.shows.put(copy);
    return copy;
  },

  delete(id: ShowId): Promise<void> {
    return db.shows.delete(id);
  },
};
