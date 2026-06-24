import { useState } from 'react';
import { Result, Select, ToolCard, ToolPage } from '@/components/ui';
import { useFixtures } from '@/hooks/useLibrary';
import { DEFAULT_PHOTOMETRY_KEY, type Fixture } from '@/models/fixture';

export function FixtureLibrary() {
  const fixtures = useFixtures();
  const [a, setA] = useState('');
  const [b, setB] = useState('');
  const fxA = fixtures.find((f) => f.id === a);
  const fxB = fixtures.find((f) => f.id === b);

  return (
    <ToolPage section={3} title="Fixture Library" intro={`${fixtures.length} fixtures. GDTF sync and PDF storage land with the sync feature.`}>
      <ToolCard title="Library">
        <ul className="fixture-list">
          {fixtures.map((f) => (
            <li key={f.id} className="fixture-row">
              <span className="fixture-meta">
                <strong>{f.manufacturer} {f.model}</strong>
                <span className="muted">{f.category} · {f.modes.length} mode{f.modes.length === 1 ? '' : 's'}</span>
              </span>
              <span className="muted">{summarise(f)}</span>
            </li>
          ))}
        </ul>
      </ToolCard>

      <ToolCard title="Comparator">
        <div className="row2">
          <Select value={a} onChange={setA} options={pickOptions(fixtures)} />
          <Select value={b} onChange={setB} options={pickOptions(fixtures)} />
        </div>
        {fxA && fxB && (
          <table className="compare-table">
            <thead>
              <tr><th /><th>{fxA.model}</th><th>{fxB.model}</th></tr>
            </thead>
            <tbody>
              <CompareRow label="Output @ 1 m (lux)" a={lux(fxA)} b={lux(fxB)} />
              <CompareRow label="Max power (W)" a={maxPower(fxA)} b={maxPower(fxB)} />
              <CompareRow label="Weight (kg)" a={fxA.weightKg ?? '—'} b={fxB.weightKg ?? '—'} />
              <CompareRow label="CRI" a={fxA.colour.cri ?? '—'} b={fxB.colour.cri ?? '—'} />
              <CompareRow label="TLCI" a={fxA.colour.tlci ?? '—'} b={fxB.colour.tlci ?? '—'} />
              <CompareRow label="Beam angle (°)" a={beam(fxA)} b={beam(fxB)} />
            </tbody>
          </table>
        )}
        {(!fxA || !fxB) && <Result label="Pick two fixtures" value="to compare side by side" />}
      </ToolCard>
    </ToolPage>
  );
}

function CompareRow({ label, a, b }: { label: string; a: number | string; b: number | string }) {
  const better = typeof a === 'number' && typeof b === 'number' && a !== b ? (a > b ? 'a' : 'b') : null;
  return (
    <tr>
      <td className="muted">{label}</td>
      <td className={better === 'a' ? 'compare-best' : ''}>{a}</td>
      <td className={better === 'b' ? 'compare-best' : ''}>{b}</td>
    </tr>
  );
}

const pickOptions = (fixtures: Fixture[]) => [
  { value: '', label: 'Select…' },
  ...fixtures.map((f) => ({ value: f.id, label: `${f.manufacturer} ${f.model}` })),
];

const lux = (f: Fixture): number | string => f.photometry[DEFAULT_PHOTOMETRY_KEY]?.luxAt1m ?? '—';
const maxPower = (f: Fixture): number | string => {
  const powers = f.modes.map((m) => m.powerW).filter((w): w is number => w !== undefined);
  return powers.length ? Math.max(...powers) : '—';
};
const beam = (f: Fixture): number | string =>
  f.beam.angleDeg ?? (f.beam.zoomRangeDeg ? `${f.beam.zoomRangeDeg.minDeg}–${f.beam.zoomRangeDeg.maxDeg}` : '—');

function summarise(f: Fixture): string {
  const parts: string[] = [];
  const l = f.photometry[DEFAULT_PHOTOMETRY_KEY]?.luxAt1m;
  if (l) parts.push(`${l} lux@1m`);
  if (f.colour.cri) parts.push(`CRI ${f.colour.cri}`);
  return parts.join(' · ');
}
