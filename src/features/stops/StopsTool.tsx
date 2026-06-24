import { useMemo, useState } from 'react';
import { Field, NumberInput, Result, Select, ToolCard, ToolPage } from '@/components/ui';
import { computeStops } from '@/services/calc';
import { useFixtures } from '@/hooks/useLibrary';
import { DEFAULT_PHOTOMETRY_KEY, type DimmingCurveType, type Photometry } from '@/models/fixture';

const CURVES: Array<{ value: DimmingCurveType; label: string }> = [
  { value: 'linear', label: 'Linear' },
  { value: 'square', label: 'Square law' },
  { value: 'scurve', label: 'S-curve' },
  { value: 'log', label: 'Logarithmic' },
];

export function StopsTool() {
  const fixtures = useFixtures();
  const [fixtureId, setFixtureId] = useState('manual');
  const [curve, setCurve] = useState<DimmingCurveType>('square');
  const [lux1m, setLux1m] = useState<number | ''>(10000);
  const [currentDmx, setCurrentDmx] = useState<number | ''>(180);

  const photometry: Photometry | null = useMemo(() => {
    if (fixtureId === 'manual') {
      return { luxAt1m: typeof lux1m === 'number' ? lux1m : undefined, dimmingCurve: { type: curve } };
    }
    const fx = fixtures.find((f) => f.id === fixtureId);
    return fx?.photometry[DEFAULT_PHOTOMETRY_KEY] ?? null;
  }, [fixtureId, curve, lux1m, fixtures]);

  const result = useMemo(() => {
    if (!photometry || typeof currentDmx !== 'number') return null;
    return computeStops(photometry, currentDmx);
  }, [photometry, currentDmx]);

  return (
    <ToolPage
      section={5}
      title="Stops Calculator"
      intro="Manual mode — pick a fixture or enter a curve, set the current DMX, read off ± stops. (Live console pull lands with console integration.)"
    >
      <ToolCard>
        <Field label="Fixture">
          <Select
            value={fixtureId}
            onChange={setFixtureId}
            options={[
              { value: 'manual', label: 'Manual entry' },
              ...fixtures.map((f) => ({ value: f.id, label: `${f.manufacturer} ${f.model}` })),
            ]}
          />
        </Field>
        {fixtureId === 'manual' ? (
          <>
            <Field label="Dimming curve">
              <Select value={curve} onChange={setCurve} options={CURVES} />
            </Field>
            <Field label="Output at 1 m (optional)">
              <NumberInput value={lux1m} onChange={setLux1m} suffix="lux" />
            </Field>
          </>
        ) : (
          <Result label="Dimming curve" value={photometry?.dimmingCurve.type ?? '—'} />
        )}
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
