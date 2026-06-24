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

const to255 = (n: number): number => Math.round(Math.min(1, Math.max(0, n)) * 255);
const round1 = (n: number): number => Math.round(n * 10) / 10;
const round3 = (n: number): number => Math.round(n * 1000) / 1000;
