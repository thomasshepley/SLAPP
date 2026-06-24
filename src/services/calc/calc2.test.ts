import { describe, expect, it } from 'vitest';
import {
  percentToCct,
  cctToPercent,
  classifyTint,
  suggestCtGel,
} from './colour';
import { apertureForExposure, equivalentExposures, F_STOPS } from './exposure';
import { bpmToRpm, rpmToBpm, deratedCapacity, recommendCable } from './reference';
import { sunTimes, sunPosition } from './sun';

describe('variable CCT', () => {
  it('maps fader % to CCT and back in mired space', () => {
    const cct = percentToCct(50, 2700, 6500);
    expect(cct).toBeGreaterThan(2700);
    expect(cct).toBeLessThan(6500);
    expect(cctToPercent(cct, 2700, 6500)).toBeCloseTo(50, 0);
  });

  it('clamps fader range', () => {
    expect(percentToCct(0, 3200, 5600)).toBe(3200);
    expect(percentToCct(100, 3200, 5600)).toBe(5600);
  });
});

describe('tint', () => {
  it('classifies green and magenta', () => {
    expect(classifyTint(0.003).direction).toBe('green');
    expect(classifyTint(-0.003).direction).toBe('magenta');
    expect(classifyTint(0).direction).toBe('neutral');
  });
});

describe('CT gel suggestion', () => {
  it('suggests CTO when warming daylight to tungsten', () => {
    const s = suggestCtGel(5600, 3200);
    expect(s.family).toBe('CTO');
  });
  it('suggests CTB when cooling tungsten to daylight', () => {
    const s = suggestCtGel(3200, 5600);
    expect(s.family).toBe('CTB');
  });
  it('suggests none for trivial shifts', () => {
    expect(suggestCtGel(5600, 5550).family).toBe('none');
  });
});

describe('exposure triangle', () => {
  it('gives a sensible aperture for a bright reading', () => {
    const { nearestStop } = apertureForExposure(8000, 100, 50);
    expect(F_STOPS).toContain(nearestStop);
  });
  it('opens up one stop when ISO doubles', () => {
    const low = apertureForExposure(2000, 100, 50).exact;
    const high = apertureForExposure(2000, 200, 50).exact;
    // higher ISO -> larger f-number (less light needed)
    expect(high).toBeGreaterThan(low);
  });
  it('builds an equivalent-exposure grid', () => {
    expect(equivalentExposures(2000, [100, 200], [25, 50])).toHaveLength(4);
  });
});

describe('gobo BPM', () => {
  it('beat mode: bpm equals rpm', () => {
    expect(bpmToRpm(120, 'beat')).toBe(120);
  });
  it('bar mode round-trips', () => {
    expect(rpmToBpm(bpmToRpm(120, 'bar', 4), 'bar', 4)).toBe(120);
  });
});

describe('cable derating', () => {
  it('derates with temperature', () => {
    expect(deratedCapacity(2.5, 30)).toBeCloseTo(25, 0);
    expect(deratedCapacity(2.5, 40)).toBeLessThan(25);
  });
  it('recommends a cable that carries the load', () => {
    const rec = recommendCable(20, 30);
    expect(rec).toBeDefined();
    expect(deratedCapacity(rec!.csaMm2, 30)).toBeGreaterThanOrEqual(20);
  });
});

describe('sun position', () => {
  // London, summer solstice 2026.
  const input = {
    date: new Date('2026-06-21T12:00:00Z'),
    latitude: 51.5,
    longitude: -0.13,
    utcOffsetHours: 1,
  };

  it('computes sunrise before sunset around the solstice', () => {
    const t = sunTimes(input);
    expect(t.sunriseMin).not.toBeNull();
    expect(t.sunsetMin).not.toBeNull();
    expect(t.sunriseMin!).toBeLessThan(t.sunsetMin!);
    // London solstice: sunrise ~04:43 BST, sunset ~21:21 BST.
    expect(t.sunriseMin! / 60).toBeGreaterThan(4);
    expect(t.sunriseMin! / 60).toBeLessThan(6);
    expect(t.sunsetMin! / 60).toBeGreaterThan(20);
  });

  it('sun is high near local noon at the solstice', () => {
    const pos = sunPosition({ ...input, date: new Date('2026-06-21T11:00:00Z') });
    expect(pos.elevation).toBeGreaterThan(55);
    expect(pos.azimuth).toBeGreaterThan(120);
    expect(pos.azimuth).toBeLessThan(220);
  });
});
