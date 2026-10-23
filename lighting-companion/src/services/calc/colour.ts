import type { Kelvin, Mired } from '@/models/common';
import type { Hsi, Rgb } from '@/models/colour';

/**
 * Colour-temperature maths for the colour tools. Mired (micro reciprocal
 * degrees) is the natural unit for CT correction because gel shifts are linear
 * in mired, not in kelvin.
 */

export const kelvinToMired = (k: Kelvin): Mired => 1_000_000 / k;
export const miredToKelvin = (m: Mired): Kelvin => 1_000_000 / m;

/**
 * CTO/CTB correction. Returns the mired shift needed to move from a source CCT
 * to a target CCT. Negative = warming (CTO, raises mired); positive = cooling
 * (CTB, lowers mired). Works in both directions by construction.
 */
export function correctionMiredShift(sourceK: Kelvin, targetK: Kelvin): Mired {
  return kelvinToMired(targetK) - kelvinToMired(sourceK);
}

/** Apply a mired shift to a source CCT, returning the resulting CCT. */
export function applyMiredShift(sourceK: Kelvin, shift: Mired): Kelvin {
  return miredToKelvin(kelvinToMired(sourceK) + shift);
}

// --- RGB / HSI ------------------------------------------------------------

/** HSI is the intuitive space for LED fixtures (intensity is separable). */
export function rgbToHsi({ r, g, b }: Rgb): Hsi {
  const rn = r / 255;
  const gn = g / 255;
  const bn = b / 255;
  const i = (rn + gn + bn) / 3;
  const min = Math.min(rn, gn, bn);
  const s = i === 0 ? 0 : 1 - min / i;
  let h = 0;
  const denom = Math.sqrt((rn - gn) ** 2 + (rn - bn) * (gn - bn));
  if (denom !== 0) {
    const cos = ((rn - gn) + (rn - bn)) / (2 * denom);
    h = Math.acos(Math.min(1, Math.max(-1, cos))) * (180 / Math.PI);
    if (bn > gn) h = 360 - h;
  }
  return { h: round1(h), s: round3(s), i: round3(i) };
}

export function hsiToRgb({ h, s, i }: Hsi): Rgb {
  const hr = (h % 360) * (Math.PI / 180);
  let r: number;
  let g: number;
  let b: number;
  const third = (2 * Math.PI) / 3;
  if (hr < third) {
    b = i * (1 - s);
    r = i * (1 + (s * Math.cos(hr)) / Math.cos(third / 2 - hr));
    g = 3 * i - (r + b);
  } else if (hr < 2 * third) {
    const h2 = hr - third;
    r = i * (1 - s);
    g = i * (1 + (s * Math.cos(h2)) / Math.cos(third / 2 - h2));
    b = 3 * i - (r + g);
  } else {
    const h2 = hr - 2 * third;
    g = i * (1 - s);
    b = i * (1 + (s * Math.cos(h2)) / Math.cos(third / 2 - h2));
    r = 3 * i - (g + b);
  }
  return { r: to255(r), g: to255(g), b: to255(b) };
}

// --- Variable-CCT fixtures ------------------------------------------------

/**
 * Map a fader position (0..100 %) to output CCT for a tunable-white fixture.
 * Tunable whites are near-linear in mired across the fader, so we interpolate
 * in mired space (not kelvin) for a result that matches the fixture's feel.
 */
export function percentToCct(percent: number, minK: Kelvin, maxK: Kelvin): Kelvin {
  const p = Math.min(1, Math.max(0, percent / 100));
  const m = kelvinToMired(minK) + p * (kelvinToMired(maxK) - kelvinToMired(minK));
  return Math.round(miredToKelvin(m));
}

export function cctToPercent(cct: Kelvin, minK: Kelvin, maxK: Kelvin): number {
  const m = kelvinToMired(cct);
  const mMin = kelvinToMired(minK);
  const mMax = kelvinToMired(maxK);
  const p = (m - mMin) / (mMax - mMin);
  return round1(Math.min(1, Math.max(0, p)) * 100);
}

// --- Duv / tint -----------------------------------------------------------

export type TintDirection = 'green' | 'magenta' | 'neutral';

export interface TintReading {
  direction: TintDirection;
  /** Magnitude of the shift, same units as Duv. */
  magnitude: number;
  /** Rough CC/plus-green eighths, the way a DoP would call it. */
  ccEighths: number;
}

/**
 * Classify a Duv value as green (+) or magenta (-) tint. Duv is distance from
 * the Planckian locus; ~0.0007 Duv ≈ one "eighth" of CC correction, a handy
 * rule of thumb for camera matching.
 */
export function classifyTint(duv: number, neutralBand = 0.0003): TintReading {
  const direction: TintDirection =
    Math.abs(duv) <= neutralBand ? 'neutral' : duv > 0 ? 'green' : 'magenta';
  return {
    direction,
    magnitude: Math.abs(round(duv, 5)),
    ccEighths: Math.round(Math.abs(duv) / 0.0007),
  };
}

// --- CT-correction gel suggestion -----------------------------------------

export interface CtGelSuggestion {
  /** 'CTO' warms (raises mired), 'CTB' cools (lowers mired). */
  family: 'CTO' | 'CTB' | 'none';
  /** Nearest standard fraction, e.g. "Full", "1/2", "1/4", "1/8". */
  strength: string;
  /** Mired shift the suggested gel provides. */
  gelMiredShift: number;
  /** Residual mired error after applying the suggested gel. */
  residualMired: number;
}

// Standard CT gel mired shifts (Lee/Rosco nominal). CTO positive (warming).
const CTO_STEPS: Array<{ label: string; mired: number }> = [
  { label: '1/8', mired: 53 },
  { label: '1/4', mired: 81 },
  { label: '1/2', mired: 137 },
  { label: 'Full', mired: 167 },
];
const CTB_STEPS: Array<{ label: string; mired: number }> = [
  { label: '1/8', mired: -49 },
  { label: '1/4', mired: -78 },
  { label: '1/2', mired: -110 },
  { label: 'Full', mired: -131 },
];

/** Suggest the closest single standard CT gel to correct source→target. */
export function suggestCtGel(sourceK: Kelvin, targetK: Kelvin): CtGelSuggestion {
  const needed = correctionMiredShift(sourceK, targetK);
  if (Math.abs(needed) < 15) {
    return { family: 'none', strength: '—', gelMiredShift: 0, residualMired: round(needed, 0) };
  }
  const steps = needed > 0 ? CTO_STEPS : CTB_STEPS;
  const family = needed > 0 ? 'CTO' : 'CTB';
  let best = steps[0]!;
  for (const step of steps) {
    if (Math.abs(step.mired - needed) < Math.abs(best.mired - needed)) best = step;
  }
  return {
    family,
    strength: best.label,
    gelMiredShift: best.mired,
    residualMired: round(needed - best.mired, 0),
  };
}

const to255 = (n: number): number => Math.round(Math.min(1, Math.max(0, n)) * 255);
const round1 = (n: number): number => Math.round(n * 10) / 10;
const round3 = (n: number): number => Math.round(n * 1000) / 1000;
const round = (n: number, dp: number): number => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};
