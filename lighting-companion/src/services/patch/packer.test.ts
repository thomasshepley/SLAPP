import { describe, expect, it } from 'vitest';
import { packPatch, type PackRequest } from './packer';
import type { Fixture } from '@/models/fixture';
import type { UniverseProfile } from '@/models/patch';
import type { FixtureId } from '@/models/common';

const fixture = (id: string, channelCount: number): Fixture =>
  ({
    id: id as FixtureId,
    manufacturer: 'X',
    model: id,
    modes: [{ name: 'std', channelCount, channels: [] }],
    photometry: {},
    colour: {},
    beam: {},
    schemaVersion: 1,
    userModified: false,
    source: { origin: 'curated' },
    createdAt: '' as never,
    updatedAt: '' as never,
  }) as Fixture;

const profile = (): UniverseProfile => ({
  name: 'test',
  universes: [
    { universe: 1, transport: 'copper', preferredFixtureIds: [] },
    { universe: 2, transport: 'copper', preferredFixtureIds: [] },
  ],
});

describe('address packer', () => {
  it('packs sequentially within a universe', () => {
    const fx = fixture('a', 10);
    const fixtures = new Map([[fx.id, fx]]);
    const reqs: PackRequest[] = [{ fixtureId: fx.id, mode: 'std', quantity: 3, labelPrefix: 'Key' }];
    const res = packPatch(reqs, profile(), fixtures);
    expect(res.items.map((i) => i.startAddress)).toEqual([1, 11, 21]);
    expect(res.items.every((i) => i.universe === 1)).toBe(true);
    expect(res.items[0]!.label).toBe('Key 1');
  });

  it('moves to the next universe when one fills up', () => {
    const fx = fixture('big', 200);
    const fixtures = new Map([[fx.id, fx]]);
    const reqs: PackRequest[] = [{ fixtureId: fx.id, mode: 'std', quantity: 3, labelPrefix: 'B' }];
    const res = packPatch(reqs, profile(), fixtures);
    // 512/200 -> 2 fit in U1 (addr 1, 201), 3rd spills to U2.
    const universes = res.items.map((i) => i.universe);
    expect(universes).toContain(2);
  });

  it('honours preferred universe assignment', () => {
    const a = fixture('a', 10);
    const b = fixture('b', 10);
    const fixtures = new Map([
      [a.id, a],
      [b.id, b],
    ]);
    const prof: UniverseProfile = {
      name: 'p',
      universes: [
        { universe: 1, transport: 'copper', preferredFixtureIds: [a.id] },
        { universe: 2, transport: 'wireless', preferredFixtureIds: [b.id] },
      ],
    };
    const res = packPatch(
      [
        { fixtureId: a.id, mode: 'std', quantity: 1, labelPrefix: 'A' },
        { fixtureId: b.id, mode: 'std', quantity: 1, labelPrefix: 'B' },
      ],
      prof,
      fixtures,
    );
    expect(res.items.find((i) => i.fixtureId === a.id)!.universe).toBe(1);
    expect(res.items.find((i) => i.fixtureId === b.id)!.universe).toBe(2);
  });

  it('flags overflow when nothing fits', () => {
    const fx = fixture('huge', 400);
    const fixtures = new Map([[fx.id, fx]]);
    const prof: UniverseProfile = {
      name: 'p',
      universes: [{ universe: 1, transport: 'copper', preferredFixtureIds: [] }],
    };
    const res = packPatch([{ fixtureId: fx.id, mode: 'std', quantity: 2, labelPrefix: 'H' }], prof, fixtures);
    // 1 fits (addr 1), 2nd (needs 400 from addr 401) overflows.
    expect(res.items).toHaveLength(1);
    expect(res.overflows.length).toBeGreaterThan(0);
  });
});
