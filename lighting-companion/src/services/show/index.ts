import type { ConsoleType } from '@/models/console';
import type { Show } from '@/models/show';
import type { UniverseProfile } from '@/models/patch';

export { applyCrossImport } from './crossImport';
export type { CrossImportResult } from './crossImport';
export { exportBundle, importBundle, bundleToJson, parseBundle } from './bundle';

/** A sensible empty universe profile: 4 copper + 8 wireless universes. */
export function defaultUniverseProfile(): UniverseProfile {
  const universes = [
    ...Array.from({ length: 4 }, (_, i) => ({
      universe: i + 1,
      transport: 'copper' as const,
      preferredFixtureIds: [],
    })),
    ...Array.from({ length: 8 }, (_, i) => ({
      universe: i + 11,
      transport: 'wireless' as const,
      preferredFixtureIds: [],
    })),
  ];
  return { name: 'Default', universes };
}

/** Fields for a brand-new show, ready to hand to showRepo.create(). */
export function newShowDraft(
  name: string,
  consoleType: ConsoleType = 'ma3',
): Omit<Show, 'id' | 'createdAt' | 'updatedAt' | 'schemaVersion'> {
  return {
    name,
    console: { type: consoleType, host: '' },
    universeProfile: defaultUniverseProfile(),
    patch: [],
  };
}
