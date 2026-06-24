import type { DimmingCurve, DimmingSample } from '@/models/fixture';

/**
 * Evaluate a fixture's dimming curve: given a DMX level (as a fraction of full,
 * 0..1) return the relative light output (0..1). This is the single source of
 * truth for the non-linearity the stops calculator depends on — square-law,
 * S-curve and log dimming all produce very different lux at the same DMX, and
 * getting stops right means modelling that here rather than assuming linear.
 */
export function outputFractionAtDmx(curve: DimmingCurve, dmxFraction: number): number {
  const x = clamp01(dmxFraction);
  switch (curve.type) {
    case 'linear':
      return x;
    case 'square':
      return x * x;
    case 'log':
      // Perceptual/log dimming: shallow at the top, steep at the bottom.
      return x === 0 ? 0 : Math.pow(x, 2.2);
    case 'scurve':
      // Smoothstep — eased at both ends.
      return x * x * (3 - 2 * x);
    case 'measured':
      return interpolateMeasured(curve.samples ?? [], x);
    default: {
      const exhaustive: never = curve.type;
      throw new Error(`Unknown dimming curve: ${String(exhaustive)}`);
    }
  }
}

/**
 * Inverse of {@link outputFractionAtDmx}: given a desired output fraction,
 * return the DMX fraction that produces it. Used to convert a target stop into
 * a settable DMX value. Monotonic curves only (all of ours are).
 */
export function dmxFractionForOutput(curve: DimmingCurve, outputFraction: number): number {
  const y = clamp01(outputFraction);
  switch (curve.type) {
    case 'linear':
      return y;
    case 'square':
      return Math.sqrt(y);
    case 'log':
      return y === 0 ? 0 : Math.pow(y, 1 / 2.2);
    case 'scurve':
      return invertSmoothstep(y);
    case 'measured':
      return invertMeasured(curve.samples ?? [], y);
    default: {
      const exhaustive: never = curve.type;
      throw new Error(`Unknown dimming curve: ${String(exhaustive)}`);
    }
  }
}

function interpolateMeasured(samples: DimmingSample[], x: number): number {
  if (samples.length === 0) return x; // fall back to linear if uncalibrated
  const sorted = [...samples].sort((a, b) => a.dmxFraction - b.dmxFraction);
  return lerpTable(
    sorted.map((s) => s.dmxFraction),
    sorted.map((s) => s.outputFraction),
    x,
  );
}

function invertMeasured(samples: DimmingSample[], y: number): number {
  if (samples.length === 0) return y;
  const sorted = [...samples].sort((a, b) => a.outputFraction - b.outputFraction);
  return lerpTable(
    sorted.map((s) => s.outputFraction),
    sorted.map((s) => s.dmxFraction),
    y,
  );
}

/** Piecewise-linear interpolation of ys(xs) at x, clamped to the end points. */
function lerpTable(xs: number[], ys: number[], x: number): number {
  if (x <= xs[0]!) return ys[0]!;
  const last = xs.length - 1;
  if (x >= xs[last]!) return ys[last]!;
  for (let i = 0; i < last; i++) {
    const x0 = xs[i]!;
    const x1 = xs[i + 1]!;
    if (x >= x0 && x <= x1) {
      const t = x1 === x0 ? 0 : (x - x0) / (x1 - x0);
      return ys[i]! + t * (ys[i + 1]! - ys[i]!);
    }
  }
  return ys[last]!;
}

/** Numerically invert smoothstep (no closed form needed at this precision). */
function invertSmoothstep(y: number): number {
  let lo = 0;
  let hi = 1;
  for (let i = 0; i < 40; i++) {
    const mid = (lo + hi) / 2;
    const v = mid * mid * (3 - 2 * mid);
    if (v < y) lo = mid;
    else hi = mid;
  }
  return (lo + hi) / 2;
}

const clamp01 = (n: number): number => Math.min(1, Math.max(0, n));
