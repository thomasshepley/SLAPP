import { useMemo, useState } from 'react';
import { Field, NumberInput, Result, Select, ToolCard, ToolPage } from '@/components/ui';
import { FixturePicker } from '@/components/FixturePicker';
import { computeStops } from '@/services/calc';
import { useFixtures } from '@/hooks/useLibrary';
import { DEFAULT_PHOTOMETRY_KEY, type DimmingCurveType, type Photometry } from '@/models/fixture';
import type { FixtureId } from '@/models/common';

const CURVES: Array<{ value: DimmingCurveType; label: string }> = [
  { value: 'linear', label: 'Linear' },
  { value: 'square', label: 'Square law' },
  { value: 'scurve', label: 'S-curve' },
  { value: 'log', label: 'Logarithmic' },
];

export function StopsTool() {
  const fixtures = useFixtures();
  const [fixtureId, setFixtureId] = useState<FixtureId | ''>('');
  const [isManual, setIsManual] = useState(true);
  const [curve, setCurve] = useState<DimmingCurveType>('square');
  const [lux1m, setLux1m] = useState<number | ''>(10000);
  const [currentDmx, setCurrentDmx] = useState<number | ''>(180);

  const photometry: Photometry | null = useMemo(() => {
    if (isManual) {
      return { luxAt1m: typeof lux1m === 'number' ? lux1m : undefined, dimmingCurve: { type: curve } };
    }
    const fx = fixtures.find((f) => f.id === fixtureId);
    return fx?.photometry[DEFAULT_PHOTOMETRY_KEY] ?? null;
  }, [fixtureId, isManual, curve, lux1m, fixtures]);

  const result = useMemo(() => {
    if (!photometry || typeof currentDmx !== 'number') return null;
    return computeStops(photometry, currentDmx);
  }, [photometry, currentDmx]);

  return (
    <ToolPage
      section={5}
      title="Stops Calculator"
      intro="Pick a fixture or enter a curve, set the current DMX, read off ± stops."
    >
      <ToolCard>
        <Field label="Fixture">
          <FixturePicker
            value={isManual ? 'manual' as FixtureId : fixtureId}
            onChange={(id) => {
              if (id === 'manual') {
                setIsManual(true);
                setFixtureId('');
              } else {
                setIsManual(false);
                setFixtureId(id);
              }
            }}
            showManualOption
          />
        </Field>
        {isManual ? (
          <>
            <Field label="Dimming curve">
              <Select value={curve} onChange={setCurve} options={CURVES} />
            </Field>
            <Field label="Output at 1 m (optional)">
              <NumberInput value={lux1m} onChange={setLux1m} suffix="lux" />
            </Field>
          </>
        ) : fixtureId ? (
          <Result label="Dimming curve" value={photometry?.dimmingCurve.type ?? '—'} />
        ) : null}
        <Field label="Current DMX" hint="0–255">
          <NumberInput value={currentDmx} onChange={setCurrentDmx} min={0} max={255} />
        </Field>
      </ToolCard>

      {result && (
        <ToolCard title="Result">
          <Result label="Current level" value={`${result.currentPercent}%`} unit={`(DMX ${result.currentDmx})`} />
          {result.currentLux !== undefined && (
            <Result label="Estimated output @ 1 m" value={Math.round(result.currentLux)} unit="lux" />
          )}
          <table className="stops-table">
            <thead>
              <tr><th>Stop</th><th>DMX</th><th>%</th><th /></tr>
            </thead>
            <tbody>
              {result.rows.map((row) => (
                <tr key={row.stops} className={row.clipped ? 'row-clipped' : ''}>
                  <td>{row.stops > 0 ? `+${row.stops}` : row.stops}</td>
                  <td>{row.dmx}</td>
                  <td>{row.percent}%</td>
                  <td>{row.clipped ? <span className="muted">out of range</span> : ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </ToolCard>
      )}
    </ToolPage>
  );
}
