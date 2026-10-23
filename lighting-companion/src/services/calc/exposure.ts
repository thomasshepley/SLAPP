import type { Lux } from '@/models/common';

/**
 * Camera & exposure helpers. EV here is referenced at ISO 100 (EV100), the
 * usual convention when going from an incident lux reading to a stills/cine
 * exposure.
 */

/**
 * Incident lux → EV at ISO 100. Standard incident relation EV = log2(E·S/C)
 * with S = 100 (ISO 100) and the flat-receptor constant C = 250, which reduces
 * to log2(lux/2.5). So 2500 lux ≈ EV 10, matching a real incident meter.
 */
export function luxToEv100(lux: Lux): number {
  if (lux <= 0) return -Infinity;
  return Math.log2((lux * 100) / 250);
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

// --- Exposure triangle ----------------------------------------------------

/** Standard full-stop f-numbers. */
export const F_STOPS = [1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11, 16, 22, 32];

export interface ExposureSuggestion {
  fNumber: number;
  iso: number;
  /** Shutter as the x in 1/x seconds. */
  shutter: number;
}

/**
 * Solve the exposure equation N² / t = (L · S) / K for aperture, given a lux
 * reading, ISO and shutter speed. K = 12.5 (reflected) is the usual stills
 * constant; for an incident reading the EV is the same, so this lines up with
 * {@link luxToEv100}. Returns the exact f-number and the nearest standard stop.
 */
export function apertureForExposure(
  lux: Lux,
  iso: number,
  shutter: number, // 1/x s
): { exact: number; nearestStop: number } {
  const t = 1 / shutter;
  const ev100 = luxToEv100(lux);
  // EV at this ISO: EV = EV100 + log2(ISO/100)
  const ev = ev100 + Math.log2(iso / 100);
  // 2^EV = N²/t  →  N = sqrt(2^EV · t)
  const nSquared = Math.pow(2, ev) * t;
  const exact = Math.sqrt(Math.max(0, nSquared));
  return { exact: round2(exact), nearestStop: nearestFStop(exact) };
}

/**
 * Build a row of equivalent exposures (same EV) around a base, walking ISO and
 * shutter so a DoP can pick a working combination. Useful when matching a
 * required depth of field or motion-blur shutter.
 */
export function equivalentExposures(
  lux: Lux,
  isos: number[],
  shutters: number[],
): ExposureSuggestion[] {
  const out: ExposureSuggestion[] = [];
  for (const iso of isos) {
    for (const shutter of shutters) {
      const { nearestStop } = apertureForExposure(lux, iso, shutter);
      out.push({ fNumber: nearestStop, iso, shutter });
    }
  }
  return out;
}

function nearestFStop(n: number): number {
  let best = F_STOPS[0]!;
  for (const f of F_STOPS) {
    if (Math.abs(Math.log2(f) - Math.log2(n)) < Math.abs(Math.log2(best) - Math.log2(n))) {
      best = f;
    }
  }
  return best;
}

const round2 = (n: number): number => Math.round(n * 100) / 100;
