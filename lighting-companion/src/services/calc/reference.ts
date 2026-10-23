/**
 * Misc on-set reference calculators that don't warrant their own module.
 */

// --- Gobo rotation ↔ BPM ---------------------------------------------------

/**
 * Convert musical tempo to gobo rotation speed. "Per beat" means one full
 * revolution per beat; "per bar" means one revolution per bar of `beatsPerBar`.
 */
export function bpmToRpm(bpm: number, mode: 'beat' | 'bar', beatsPerBar = 4): number {
  const revsPerMinute = mode === 'beat' ? bpm : bpm / beatsPerBar;
  return round2(revsPerMinute);
}

export function rpmToBpm(rpm: number, mode: 'beat' | 'bar', beatsPerBar = 4): number {
  const bpm = mode === 'beat' ? rpm : rpm * beatsPerBar;
  return round2(bpm);
}

// --- Cable current-carrying capacity (derating reference) ------------------
// Indicative figures for flexible cable (BS 7919 / manufacturer typical) at
// 30 °C ambient, single circuit, free air. These are a guide for on-set sizing,
// not a substitute for a proper installation calculation.

export interface CableRating {
  csaMm2: number; // conductor cross-sectional area
  baseAmps: number; // capacity at 30 °C reference
}

export const CABLE_RATINGS: CableRating[] = [
  { csaMm2: 1.0, baseAmps: 14 },
  { csaMm2: 1.5, baseAmps: 18 },
  { csaMm2: 2.5, baseAmps: 25 },
  { csaMm2: 4.0, baseAmps: 34 },
  { csaMm2: 6.0, baseAmps: 43 },
  { csaMm2: 10.0, baseAmps: 60 },
  { csaMm2: 16.0, baseAmps: 80 },
  { csaMm2: 25.0, baseAmps: 101 },
];

/**
 * Ambient-temperature derating factors for general-purpose PVC/rubber flex,
 * keyed by ambient °C (BS 7671 Table 4B1, 70 °C conductor). Interpolated.
 */
const TEMP_DERATE: Array<{ tempC: number; factor: number }> = [
  { tempC: 25, factor: 1.03 },
  { tempC: 30, factor: 1.0 },
  { tempC: 35, factor: 0.94 },
  { tempC: 40, factor: 0.87 },
  { tempC: 45, factor: 0.79 },
  { tempC: 50, factor: 0.71 },
  { tempC: 55, factor: 0.61 },
  { tempC: 60, factor: 0.5 },
];

export function temperatureDerateFactor(ambientC: number): number {
  const pts = TEMP_DERATE;
  if (ambientC <= pts[0]!.tempC) return pts[0]!.factor;
  const last = pts.length - 1;
  if (ambientC >= pts[last]!.tempC) return pts[last]!.factor;
  for (let i = 0; i < last; i++) {
    const a = pts[i]!;
    const b = pts[i + 1]!;
    if (ambientC >= a.tempC && ambientC <= b.tempC) {
      const t = (ambientC - a.tempC) / (b.tempC - a.tempC);
      return round2(a.factor + t * (b.factor - a.factor));
    }
  }
  return 1;
}

/** Effective capacity of a cable size at an ambient temperature. */
export function deratedCapacity(csaMm2: number, ambientC: number): number {
  const rating = CABLE_RATINGS.find((r) => r.csaMm2 === csaMm2);
  if (!rating) return 0;
  return round1(rating.baseAmps * temperatureDerateFactor(ambientC));
}

/** Smallest cable size that carries `amps` at the given ambient temperature. */
export function recommendCable(amps: number, ambientC: number): CableRating | undefined {
  return CABLE_RATINGS.find((r) => deratedCapacity(r.csaMm2, ambientC) >= amps);
}

const round1 = (n: number): number => Math.round(n * 10) / 10;
const round2 = (n: number): number => Math.round(n * 100) / 100;
