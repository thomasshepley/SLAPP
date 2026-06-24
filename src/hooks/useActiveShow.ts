import { useLiveQuery } from 'dexie-react-hooks';
import { db, settingsRepo } from '@/db';
import type { Show } from '@/models/show';
import { APP_SETTINGS_ID } from '@/models/settings';
import type { ShowId } from '@/models/common';

export function useActiveShow(): {
  show: Show | null;
  setActiveShow: (id: ShowId | undefined) => Promise<void>;
} {
  const show =
    useLiveQuery(async () => {
      const settings = await db.settings.get(APP_SETTINGS_ID);
      if (!settings?.activeShowId) return null;
      return (await db.shows.get(settings.activeShowId)) ?? null;
    }, []) ?? null;

  const setActiveShow = async (id: ShowId | undefined) => {
    await settingsRepo.update({ activeShowId: id });
  };

  return { show, setActiveShow };
}
