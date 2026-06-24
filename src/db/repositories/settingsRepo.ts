import { db } from '../database';
import {
  APP_SETTINGS_ID,
  DEFAULT_APP_SETTINGS,
  type AppSettings,
} from '@/models/settings';

/** Single-row settings access, seeded with defaults on first read. */
export const settingsRepo = {
  async get(): Promise<AppSettings> {
    const existing = await db.settings.get(APP_SETTINGS_ID);
    if (existing) return existing;
    await db.settings.put(DEFAULT_APP_SETTINGS);
    return DEFAULT_APP_SETTINGS;
  },

  async update(patch: Partial<Omit<AppSettings, 'id'>>): Promise<AppSettings> {
    const current = await this.get();
    const next: AppSettings = { ...current, ...patch, id: APP_SETTINGS_ID };
    await db.settings.put(next);
    return next;
  },
};
