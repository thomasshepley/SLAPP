import type { DmxValue, Lux } from '@/models/common';
import type { Photometry } from '@/models/fixture';
import { dmxFractionForOutput, outputFractionAtDmx } from './dimming';

/**
 * Stops calculator. A photographic "stop" is a doubling/halving of light, so
 * +1 stop = ×2 output, -1 stop = ×0.5. Given a fixture's current DMX and its
 * dimming curve, we work out the current output, scale it by the stop offset,
 * then invert the curve to find the DMX that lands there.
 */

export interface StopRow {
  stops: number; // e.g. -2, -1, +1, +2
  /** Target output relative to full (0..1); >1 means unreachable (clipped). */
  outputFraction: number;
  dmx: DmxValue; // 0..255
  percent: number; // 0..100
  /** True when the requested stop exceeds the fixture's range. */
  clipped: boolean;
}

export interface StopsResult {
  currentDmx: DmxValue;
  currentPercent: number;
  /** Estimated current output at 1 m, when the fixture has luxAt1m. */
  currentLux?: Lux;
  rows: StopRow[];
}

const DEFAULT_OFFSETS = [-2, -1, 1, 2];

export function computeStops(
  photometry: Photometry,
  currentDmx: DmxValue,
  offsets: number[] = DEFAULT_OFFSETS,
): StopsResult {
  const currentFraction = clamp01(currentDmx / 255);
  const currentOutput = outputFractionAtDmx(photometry.dimmingCurve, currentFraction);

  const rows: StopRow[] = offsets.map((stops) => {
    const targetOutput = currentOutput * Math.pow(2, stops);
    const clipped = targetOutput > 1 || targetOutput < 0;
    const reachable = clamp01(targetOutput);
    const dmxFraction = dmxFractionForOutput(photometry.dimmingCurve, reachable);
    const dmx = Math.round(dmxFraction * 255);
    return {
      stops,
      outputFraction: targetOutput,
      dmx,
      percent: round1((dmx / 255) * 100),
      clipped,
    };
  });

  return {
    currentDmx,
    currentPercent: round1(currentFraction * 100),
    currentLux:
      photometry.luxAt1m !== undefined ? photometry.luxAt1m * currentOutput : undefined,
    rows,
  };
}

const clamp01 = (n: number): number => Math.min(1, Math.max(0, n));
const round1 = (n: number): number => Math.round(n * 10) / 10;
