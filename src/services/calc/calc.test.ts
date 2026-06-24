import { describe, expect, it } from 'vitest';
import { outputFractionAtDmx, dmxFractionForOutput } from './dimming';
import { computeStops } from './stops';
import { luxAtDistance, distanceForLux, beamDiameterAt } from './photometry';
import { kelvinToMired, correctionMiredShift, applyMiredShift, rgbToHsi, hsiToRgb } from './colour';
import { stackNd, ndDensityToStops, checkFlicker, luxToEv100 } from './exposure';
import { computePowerBudget } from './power';
import type { Photometry } from '@/models/fixture';

describe('dimming curves', () => {
  it('square law halves-to-quarter correctly and round-trips', () => {
    expect(outputFractionAtDmx({ type: 'square' }, 0.5)).toBeCloseTo(0.25);
    expect(dmxFractionForOutput({ type: 'square' }, 0.25)).toBeCloseTo(0.5);
  });

  it('interpolates measured samples', () => {
    const curve = {
      type: 'measured' as const,
      samples: [
        { dmxFraction: 0, outputFraction: 0 },
        { dmxFraction: 0.5, outputFraction: 0.1 },
        { dmxFraction: 1, outputFraction: 1 },
      ],
    };
    expect(outputFractionAtDmx(curve, 0.25)).toBeCloseTo(0.05);
    expect(outputFractionAtDmx(curve, 0.75)).toBeCloseTo(0.55);
  });
});

describe('stops calculator', () => {
  it('+1 stop doubles output on a linear fixture', () => {
    const photometry: Photometry = { luxAt1m: 1000, dimmingCurve: { type: 'linear' } };
    const res = computeStops(photometry, 128, [1, -1]);
    const plus = res.rows.find((r) => r.stops === 1)!;
    const minus = res.rows.find((r) => r.stops === -1)!;
    // current output ~0.502, +1 stop -> ~1.0 (near clip), -1 -> ~0.25 dmx
    expect(minus.dmx).toBeCloseTo(64, 0);
    expect(plus.dmx).toBeCloseTo(255, 0);
  });

  it('reports current lux from photometry', () => {
    const photometry: Photometry = { luxAt1m: 1000, dimmingCurve: { type: 'linear' } };
    const res = computeStops(photometry, 255, []);
    expect(res.currentLux).toBeCloseTo(1000);
  });
});

describe('photometry', () => {
  it('inverse square law', () => {
    expect(luxAtDistance(1000, 2)).toBeCloseTo(250);
    expect(distanceForLux(1000, 250)).toBeCloseTo(2);
  });

  it('beam diameter at distance', () => {
    // 90deg beam at 5m -> diameter 10m
    expect(beamDiameterAt(90, 5)).toBeCloseTo(10);
  });
});

describe('colour temperature', () => {
  it('kelvin/mired conversion', () => {
    expect(kelvinToMired(10000)).toBeCloseTo(100);
  });

  it('CTO/CTB shift is reversible', () => {
    const shift = correctionMiredShift(5600, 3200);
    expect(applyMiredShift(5600, shift)).toBeCloseTo(3200, 0);
  });

  it('rgb/hsi round-trips for a saturated colour', () => {
    const hsi = rgbToHsi({ r: 255, g: 0, b: 0 });
    const rgb = hsiToRgb(hsi);
    expect(rgb.r).toBeGreaterThan(240);
  });
});

describe('exposure', () => {
  it('ND density to stops', () => {
    expect(ndDensityToStops(0.9)).toBeCloseTo(3, 1);
  });

  it('stacks ND filters', () => {
    expect(stackNd([0.3, 0.6]).totalStops).toBeCloseTo(3, 1);
  });

  it('flags flicker-safe shutter at 50Hz', () => {
    expect(checkFlicker(100, 50).safe).toBe(true);
    expect(checkFlicker(125, 50).safe).toBe(false);
  });

  it('converts lux to EV100', () => {
    expect(luxToEv100(2500)).toBeCloseTo(Math.log2(2500 / 250), 5);
  });
});

describe('power budget', () => {
  it('totals watts and amps and flags over-distro', () => {
    const res = computePowerBudget({
      voltage: 230,
      distroRatingA: 13,
      items: [
        { fixtureId: 'a' as never, mode: 'std', quantity: 4, perUnitW: 1000 },
      ],
    });
    expect(res.totalW).toBe(4000);
    expect(res.totalA).toBeCloseTo(17.39, 1);
    expect(res.overDistro).toBe(true);
  });
});
