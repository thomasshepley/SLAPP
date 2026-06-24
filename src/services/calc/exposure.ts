import type { Lux } from '@/models/common';

/**
 * Camera & exposure helpers. EV here is referenced at ISO 100 (EV100), the
 * usual convention when going from an incident lux reading to a stills/cine
 * exposure.
 */

/** Incident lux → EV at ISO 100. Uses the standard incident constant C = 250. */
export function luxToEv100(lux: Lux): number {
  if (lux <= 0) return -Infinity;
  return Math.log2((lux * 100) / (250 * 100));
}

/** ND value (optical density) → stops of light lost (×0.3 density ≈ 1 stop). */
export function ndDensityToStops(density: number): number {
  return density / 0.3010299957; // log10(2)
}

export function stopsToNdDensity(stops: number): number {
  return stops * 0.3010299957;
}

/** Stack of ND filters: total density adds, stops add. */
export function stackNd(densities: number[]): { totalDensity: number; totalStops: number } {
  const totalDensity = densities.reduce((a, d) => a + d, 0);
  return { totalDensity: round2(totalDensity), totalStops: round2(ndDensityToStops(totalDensity)) };
}

/**
 * Flicker-free shutter check. A shutter is flicker-safe with mains-powered
 * (non-flicker-free) lamps when its duration spans a whole number of mains
 * half-cycles. Returns whether the given shutter is safe and the nearest safe
 * shutter speeds either side.
 */
export interface FlickerCheck {
  safe: boolean;
  /** Mains flickers per second (2 × mains frequency). */
  flickerHz: number;
  /** Safe shutter speeds (1/x s) bracketing the requested one. */
  nearestSafe: number[];
}

export function checkFlicker(
  shutterSpeed: number, // as the x in 1/x seconds
  mainsHz: 50 | 60,
): FlickerCheck {
  const flickerHz = mainsHz * 2;
  // Safe shutter speeds are integer multiples of the flicker frequency.
  const ratio = shutterSpeed / flickerHz;
  const safe = Math.abs(ratio - Math.round(ratio)) < 1e-6 && shutterSpeed >= flickerHz;
  const lower = Math.max(1, Math.floor(ratio)) * flickerHz;
  const upper = Math.ceil(ratio + 1e-9) * flickerHz;
  return { safe, flickerHz, nearestSafe: Array.from(new Set([lower, upper])) };
}

const round2 = (n: number): number => Math.round(n * 100) / 100;
