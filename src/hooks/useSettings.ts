import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '@/db';
import { APP_SETTINGS_ID, DEFAULT_APP_SETTINGS, type AppSettings } from '@/models/settings';

/**
 * Reactive app settings. Returns defaults until the row is loaded (and if it has
 * never been written), so callers always get a usable object. Tools read their
 * defaults (supply voltage, mains frequency, units) from here.
 */
export function useSettings(): AppSettings {
  return (
    useLiveQuery(async () => (await db.settings.get(APP_SETTINGS_ID)) ?? DEFAULT_APP_SETTINGS, []) ??
    DEFAULT_APP_SETTINGS
  );
}
