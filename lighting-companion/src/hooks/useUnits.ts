import { useEffect, useMemo, useRef, useState } from 'react';
import { useSettings } from './useSettings';
import { makeUnits, type Measure, type Units } from '@/services/units';

/** Reactive unit system + converters, driven by the app settings toggle. */
export function useUnits(): Units {
  const settings = useSettings();
  return useMemo(() => makeUnits(settings.units), [settings.units]);
}

/**
 * Numeric input state that is stored canonically (metric) but shown and typed in
 * the active unit. Returns the display value + setter for the `NumberInput`, and
 * the canonical value (metric, or '' when blank) for feeding the calculators.
 *
 * When the unit system flips, the on-screen number is re-expressed in the new
 * unit while the underlying canonical value stays put — so a 3 m throw becomes
 * 9.84 ft, not a silently different distance.
 */
export function useMeasure(
  initialCanonical: number,
  measure: Measure,
): readonly [number | '', (v: number | '') => void, number | ''] {
  const round2 = (n: number) => Math.round(n * 100) / 100;
  const canonicalRef = useRef<number | ''>(initialCanonical);
  const [display, setDisplay] = useState<number | ''>(() => round2(measure.toDisplay(initialCanonical)));

  // Re-express the visible number when the unit label changes (system toggled).
  const prevUnit = useRef(measure.unit);
  useEffect(() => {
    if (prevUnit.current === measure.unit) return;
    prevUnit.current = measure.unit;
    setDisplay(canonicalRef.current === '' ? '' : round2(measure.toDisplay(canonicalRef.current)));
  }, [measure]);

  const set = (v: number | '') => {
    setDisplay(v);
    canonicalRef.current = v === '' ? '' : measure.fromDisplay(v);
  };

  const canonical: number | '' = display === '' ? '' : measure.fromDisplay(display);
  return [display, set, canonical] as const;
}
