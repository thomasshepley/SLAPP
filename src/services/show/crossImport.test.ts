import { describe, expect, it } from 'vitest';
import { applyCrossImport } from './crossImport';
import type { Show } from '@/models/show';
import type { PatchItem } from '@/models/patch';
import type { FixtureId, PatchItemId, ShowId } from '@/models/common';

const item = (over: Partial<PatchItem>): PatchItem => ({
  id: 'p' as PatchItemId,
  fixtureId: 'fx' as FixtureId,
  mode: 'std',
  label: 'L',
  universe: 1,
  startAddress: 1,
  footprint: 4,
  ...over,
});

const show = (patch: PatchItem[]): Show =>
  ({
    id: 's' as ShowId,
    name: 'x',
    schemaVersion: 1,
    createdAt: '' as never,
    updatedAt: '' as never,
    console: { type: 'ma3', host: '' },
    universeProfile: { name: 'd', universes: [] },
    patch,
  }) as Show;

describe('cross-show import', () => {
  it('merges non-overlapping patches', () => {
    const current = show([item({ id: 'a' as PatchItemId, universe: 1, startAddress: 1 })]);
    const source = show([item({ id: 'b' as PatchItemId, universe: 1, startAddress: 5 })]);
    const res = applyCrossImport(current, source, {
      sourceShowId: 's' as ShowId,
      importPatch: 'all',
      importUniverseProfile: false,
      importPowerBudget: false,
      importNotes: false,
      conflictStrategy: 'merge',
    });
    expect(res.patch).toHaveLength(2);
    expect(res.clashes).toHaveLength(0);
  });

  it('flags an address clash and skips the conflicting item', () => {
    const current = show([item({ id: 'a' as PatchItemId, universe: 1, startAddress: 1, footprint: 4 })]);
    const source = show([item({ id: 'b' as PatchItemId, universe: 1, startAddress: 3, footprint: 4, label: 'Clasher' })]);
    const res = applyCrossImport(current, source, {
      sourceShowId: 's' as ShowId,
      importPatch: 'all',
      importUniverseProfile: false,
      importPowerBudget: false,
      importNotes: false,
      conflictStrategy: 'merge',
    });
    expect(res.patch).toHaveLength(1); // conflicting item not merged
    expect(res.clashes).toHaveLength(1);
    expect(res.clashes[0]!.incomingLabel).toBe('Clasher');
  });

  it('replace strategy takes only the incoming patch', () => {
    const current = show([item({ id: 'a' as PatchItemId })]);
    const source = show([
      item({ id: 'b' as PatchItemId, startAddress: 1 }),
      item({ id: 'c' as PatchItemId, startAddress: 10 }),
    ]);
    const res = applyCrossImport(current, source, {
      sourceShowId: 's' as ShowId,
      importPatch: 'all',
      importUniverseProfile: false,
      importPowerBudget: false,
      importNotes: false,
      conflictStrategy: 'replace',
    });
    expect(res.patch).toHaveLength(2);
    expect(res.patch.every((p) => p.id !== 'a')).toBe(true);
  });

  it('imports only selected fixture types', () => {
    const current = show([]);
    const source = show([
      item({ id: 'b' as PatchItemId, fixtureId: 'keep' as FixtureId, startAddress: 1 }),
      item({ id: 'c' as PatchItemId, fixtureId: 'drop' as FixtureId, startAddress: 10 }),
    ]);
    const res = applyCrossImport(current, source, {
      sourceShowId: 's' as ShowId,
      importPatch: { fixtureIds: ['keep'] },
      importUniverseProfile: false,
      importPowerBudget: false,
      importNotes: false,
      conflictStrategy: 'merge',
    });
    expect(res.patch).toHaveLength(1);
    expect(res.patch[0]!.fixtureId).toBe('keep');
  });
});
