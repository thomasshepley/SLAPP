/**
 * Unit conversion at the UI edge. Storage and every calculator work in
 * canonical metric (metres, lux, kilograms); we convert only when showing or
 * accepting a value in the user's chosen system. Keeping one canonical unit per
 * quantity is what stops unit ambiguity from creeping into the maths.
 */

export type UnitSystem = 'metric' | 'imperial';

const FEET_PER_M = 3.280839895;
const LUX_PER_FC = 10.763910417;
const LB_PER_KG = 2.204622622;

const round = (n: number, dp: number): number => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};

/** A quantity's conversion + display helpers, bound to a chosen unit system. */
export interface Measure {
  /** Unit label for the active system, e.g. "ft" or "m". */
  unit: string;
  /** Canonical (metric) → number shown to the user. */
  toDisplay(canonical: number): number;
  /** User-entered number → canonical (metric). */
  fromDisplay(display: number): number;
  /** Canonical → rounded display string (no unit). */
  format(canonical: number, dp?: number): string;
}

function makeMeasure(
  system: UnitSystem,
  metricUnit: string,
  imperialUnit: string,
  perMetric: number, // display units per one canonical unit (imperial)
  defaultDp: number,
): Measure {
  const imperial = system === 'imperial';
  return {
    unit: imperial ? imperialUnit : metricUnit,
    toDisplay: (c) => (imperial ? c * perMetric : c),
    fromDisplay: (d) => (imperial ? d / perMetric : d),
    format(c, dp = defaultDp) {
      const v = imperial ? c * perMetric : c;
      return round(v, dp).toLocaleString(undefined, { maximumFractionDigits: dp });
    },
  };
}

export interface Units {
  system: UnitSystem;
  /** Distance / throw: metres ↔ feet. */
  dist: Measure;
  /** Illuminance: lux ↔ footcandles. */
  lux: Measure;
  /** Mass: kilograms ↔ pounds. */
  mass: Measure;
}

export function makeUnits(system: UnitSystem): Units {
  return {
    system,
    dist: makeMeasure(system, 'm', 'ft', FEET_PER_M, 2),
    lux: makeMeasure(system, 'lux', 'fc', 1 / LUX_PER_FC, 0),
    mass: makeMeasure(system, 'kg', 'lb', LB_PER_KG, 1),
  };
}
