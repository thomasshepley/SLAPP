import { describe, expect, it } from 'vitest';
import { seedFixtures } from './fixtures';

const fixtures = seedFixtures();
const byKey = (frag: string) =>
  fixtures.find((f) => `${f.manufacturer} ${f.model}`.toLowerCase().includes(frag.toLowerCase()));

describe('seed fixture mode enrichment', () => {
  it('gives every fixture at least one mode', () => {
    expect(fixtures.every((f) => f.modes.length >= 1)).toBe(true);
  });

  it('declares a channelCount that covers every modeled channel', () => {
    // Curated seeds may declare the real footprint (larger than the minimal
    // modeled channel list); generated personalities match exactly. Either way
    // the count must never undercut an addressed slot.
    for (const f of fixtures) {
      for (const m of f.modes) {
        const footprint = m.channels.reduce(
          (max, c) => Math.max(max, c.offset + c.resolution / 8),
          0,
        );
        expect(m.channelCount).toBeGreaterThanOrEqual(footprint);
        expect(m.channelCount).toBeGreaterThan(0);
      }
    }
  });

  it('never emits duplicate mode names within a fixture', () => {
    for (const f of fixtures) {
      const names = f.modes.map((m) => m.name.toLowerCase());
      expect(new Set(names).size).toBe(names.length);
    }
  });

  it('gives a colour tube a rich pixel + colour personality set', () => {
    const titan = byKey('Titan Tube');
    expect(titan).toBeDefined();
    expect(titan!.modes.length).toBeGreaterThanOrEqual(10);
    // pixel personalities present
    expect(titan!.modes.some((m) => /Pixel 16-cell/i.test(m.name))).toBe(true);
    // a 16-cell RGBWA pixel mode is 1 master + 16*5 = 81 slots
    const p16 = titan!.modes.find((m) => /Pixel 16-cell/i.test(m.name));
    expect(p16!.channelCount).toBe(81);
  });

  it('gives a single-colour tungsten unit just dimmer personalities', () => {
    const t2 = byKey('ARRI 2K') ?? byKey('T2');
    expect(t2).toBeDefined();
    // no colour-mixing → only Dimmer / Dimmer 16-bit
    expect(t2!.modes.every((m) => !m.channels.some((c) => c.attribute === 'red'))).toBe(true);
    expect(t2!.modes.some((m) => m.name === 'Dimmer')).toBe(true);
  });

  it('gives a bi-colour COB CCT personalities but no pixel modes', () => {
    const forza = byKey('Forza 300B II');
    expect(forza).toBeDefined();
    expect(forza!.modes.some((m) => m.name.startsWith('CCT'))).toBe(true);
    expect(forza!.modes.some((m) => /Pixel/i.test(m.name))).toBe(false);
  });
});
