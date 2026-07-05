import { useRef, useState } from 'react';
import { Field, Result, Select, TextInput, ToolCard, ToolPage } from '@/components/ui';
import { useFixtures } from '@/hooks/useLibrary';
import { useUnits } from '@/hooks/useUnits';
import { fixtureRepo } from '@/db';
import { parseGdtf } from '@/services/gdtf';
import { DEFAULT_PHOTOMETRY_KEY, type Fixture, type FixtureMode } from '@/models/fixture';
import type { Units } from '@/services/units';

export function FixtureLibrary() {
  const fixtures = useFixtures();
  const u = useUnits();
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [activeMode, setActiveMode] = useState<Record<string, string>>({});
  const [search, setSearch] = useState('');
  const [a, setA] = useState('');
  const [b, setB] = useState('');
  const fxA = fixtures.find((f) => f.id === a);
  const fxB = fixtures.find((f) => f.id === b);

  const [importStatus, setImportStatus] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const filtered = search.trim()
    ? fixtures.filter((f) => {
        const q = search.trim().toLowerCase();
        return (
          f.manufacturer.toLowerCase().includes(q) ||
          f.model.toLowerCase().includes(q) ||
          (f.category ?? '').toLowerCase().includes(q)
        );
      })
    : fixtures;

  const grouped = groupByManufacturer(filtered);

  const handleGdtfImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files?.length) return;
    let imported = 0;
    let warnings: string[] = [];
    for (const file of Array.from(files)) {
      try {
        const buf = await file.arrayBuffer();
        const result = parseGdtf(buf);
        await fixtureRepo.put(result.fixture);
        imported++;
        if (result.warnings.length) warnings.push(...result.warnings.map((w) => `${file.name}: ${w}`));
      } catch (err) {
        warnings.push(`${file.name}: ${err instanceof Error ? err.message : 'Unknown error'}`);
      }
    }
    setImportStatus(
      `Imported ${imported} fixture${imported !== 1 ? 's' : ''}` +
        (warnings.length ? `. Warnings: ${warnings.join('; ')}` : '.'),
    );
    if (fileRef.current) fileRef.current.value = '';
    setTimeout(() => setImportStatus(null), 8000);
  };

  const handleDelete = async (fx: Fixture) => {
    if (!confirm(`Delete "${fx.manufacturer} ${fx.model}" from the library?`)) return;
    await fixtureRepo.delete(fx.id);
    if (expandedId === fx.id) setExpandedId(null);
  };

  return (
    <ToolPage
      title="Fixture Library"
      intro={`${fixtures.length} fixtures across ${groupByManufacturer(fixtures).length} brands.`}
    >
      <ToolCard title="Search & Import">
        <TextInput value={search} onChange={setSearch} placeholder="Search by name, brand, or type..." />
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
          <label className="btn" style={{ cursor: 'pointer' }}>
            Import .gdtf
            <input
              ref={fileRef}
              type="file"
              accept=".gdtf,.zip"
              multiple
              style={{ display: 'none' }}
              onChange={handleGdtfImport}
            />
          </label>
          <span className="muted" style={{ fontSize: '0.82rem' }}>
            Download .gdtf files from gdtf-share.com
          </span>
        </div>
        {importStatus && <p className="status-line">{importStatus}</p>}
        {search && filtered.length === 0 && (
          <p className="muted">No fixtures match "{search}".</p>
        )}
      </ToolCard>

      {grouped.map(([brand, brandFixtures]) => (
        <ToolCard key={brand} title={`${brand} (${brandFixtures.length})`}>
          <ul className="fixture-list">
            {brandFixtures.map((f) => {
              const isExpanded = expandedId === f.id;
              const currentModeName = activeMode[f.id] ?? f.modes[0]?.name ?? '';
              const currentMode = f.modes.find((m) => m.name === currentModeName) ?? f.modes[0];

              return (
                <li key={f.id}>
                  <button
                    className="fixture-row"
                    style={{ width: '100%', textAlign: 'left', cursor: 'pointer' }}
                    onClick={() => setExpandedId(isExpanded ? null : f.id)}
                  >
                    <span className="fixture-meta">
                      <strong>{f.model}</strong>
                      <span className="muted">
                        {f.category} · {f.modes.length} mode{f.modes.length === 1 ? '' : 's'}
                        {' · '}{summarise(f, u)}
                      </span>
                    </span>
                    <span className="muted" style={{ fontSize: '1.1rem' }}>{isExpanded ? '−' : '+'}</span>
                  </button>

                  {isExpanded && currentMode && (
                    <div style={{ padding: '12px 8px 4px', display: 'flex', flexDirection: 'column', gap: 12 }}>
                      {f.modes.length > 1 && (
                        <Field label={`DMX mode (${f.modes.length} available)`}>
                          {f.modes.length > 6 ? (
                            <Select
                              value={currentModeName}
                              onChange={(name) => setActiveMode({ ...activeMode, [f.id]: name })}
                              options={f.modes.map((m) => ({ value: m.name, label: `${m.name} — ${m.channelCount} ch` }))}
                            />
                          ) : (
                            <div className="mode-tabs">
                              {f.modes.map((m) => (
                                <button
                                  key={m.name}
                                  className={`mode-tab${m.name === currentModeName ? ' mode-tab-active' : ''}`}
                                  onClick={() => setActiveMode({ ...activeMode, [f.id]: m.name })}
                                >
                                  {m.name} ({m.channelCount}ch)
                                </button>
                              ))}
                            </div>
                          )}
                        </Field>
                      )}

                      <div className="mode-summary">
                        <span><strong>{currentMode.channelCount}</strong> ch footprint</span>
                        {currentMode.powerW !== undefined && <span>{currentMode.powerW} W</span>}
                        <span>{currentMode.channels.length} mapped</span>
                      </div>

                      <div className="dmx-scroll">
                        <DmxChart mode={currentMode} />
                      </div>

                      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                        <Result label="Output @ 1m" value={fmtLux(f, u)} unit={u.lux.unit} />
                        <Result label="Max power" value={maxPower(f)} unit="W" />
                        {f.weightKg && <Result label="Weight" value={u.mass.format(f.weightKg)} unit={u.mass.unit} />}
                        {f.colour.cri && <Result label="CRI" value={f.colour.cri} />}
                        {f.colour.tlci && <Result label="TLCI" value={f.colour.tlci} />}
                        <Result label="Beam" value={beam(f)} unit="°" />
                        {f.colour.cctRange && (
                          <Result label="CCT range" value={`${f.colour.cctRange.minK}–${f.colour.cctRange.maxK}`} unit="K" />
                        )}
                        {f.colour.nativeCct && !f.colour.cctRange && (
                          <Result label="CCT" value={f.colour.nativeCct} unit="K" />
                        )}
                        <Result label="Dimming curve" value={f.photometry[DEFAULT_PHOTOMETRY_KEY]?.dimmingCurve.type ?? '—'} />
                        <Result label="Source" value={f.source.origin} />
                      </div>

                      <button
                        className="chip"
                        style={{ alignSelf: 'flex-start', color: '#ff5c5c', borderColor: '#ff5c5c40' }}
                        onClick={() => handleDelete(f)}
                      >
                        Delete fixture
                      </button>
                    </div>
                  )}
                </li>
              );
            })}
          </ul>
        </ToolCard>
      ))}

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
              <CompareRow label={`Output @ 1 m (${u.lux.unit})`} a={lux(fxA)} b={lux(fxB)} format={(v) => u.lux.format(v)} />
              <CompareRow label="Max power (W)" a={maxPower(fxA)} b={maxPower(fxB)} />
              <CompareRow label={`Weight (${u.mass.unit})`} a={fxA.weightKg ?? '—'} b={fxB.weightKg ?? '—'} format={(v) => u.mass.format(v)} />
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

function DmxChart({ mode }: { mode: FixtureMode }) {
  if (mode.channels.length === 0) {
    return <p className="muted" style={{ fontSize: '0.85rem' }}>No channel detail available for this mode.</p>;
  }
  return (
    <table className="dmx-table">
      <thead>
        <tr>
          <th>Ch</th>
          <th>Label</th>
          <th>Attribute</th>
          <th>Res</th>
        </tr>
      </thead>
      <tbody>
        {mode.channels.map((ch) => (
          <tr key={ch.offset}>
            <td>{ch.offset + 1}</td>
            <td>{ch.label}</td>
            <td><span className="dmx-attr">{ch.attribute}</span></td>
            <td className="muted">{ch.resolution}bit</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function CompareRow({
  label,
  a,
  b,
  format,
}: {
  label: string;
  a: number | string;
  b: number | string;
  format?: (v: number) => string;
}) {
  const better = typeof a === 'number' && typeof b === 'number' && a !== b ? (a > b ? 'a' : 'b') : null;
  const show = (v: number | string) => (typeof v === 'number' && format ? format(v) : v);
  return (
    <tr>
      <td className="muted">{label}</td>
      <td className={better === 'a' ? 'compare-best' : ''}>{show(a)}</td>
      <td className={better === 'b' ? 'compare-best' : ''}>{show(b)}</td>
    </tr>
  );
}

function groupByManufacturer(fixtures: Fixture[]): [string, Fixture[]][] {
  const map = new Map<string, Fixture[]>();
  for (const f of fixtures) {
    const list = map.get(f.manufacturer) ?? [];
    list.push(f);
    map.set(f.manufacturer, list);
  }
  return [...map.entries()].sort(([a], [b]) => a.localeCompare(b));
}

const pickOptions = (fixtures: Fixture[]) => [
  { value: '', label: 'Select...' },
  ...fixtures.map((f) => ({ value: f.id, label: `${f.manufacturer} ${f.model}` })),
];

const lux = (f: Fixture): number | string => f.photometry[DEFAULT_PHOTOMETRY_KEY]?.luxAt1m ?? '—';
const fmtLux = (f: Fixture, u: Units): string => {
  const l = f.photometry[DEFAULT_PHOTOMETRY_KEY]?.luxAt1m;
  return l !== undefined ? u.lux.format(l) : '—';
};
const maxPower = (f: Fixture): number | string => {
  const powers = f.modes.map((m) => m.powerW).filter((w): w is number => w !== undefined);
  return powers.length ? Math.max(...powers) : '—';
};
const beam = (f: Fixture): number | string =>
  f.beam.angleDeg ?? (f.beam.zoomRangeDeg ? `${f.beam.zoomRangeDeg.minDeg}–${f.beam.zoomRangeDeg.maxDeg}` : '—');

function summarise(f: Fixture, u: Units): string {
  const parts: string[] = [];
  const l = f.photometry[DEFAULT_PHOTOMETRY_KEY]?.luxAt1m;
  if (l) parts.push(`${u.lux.format(l)} ${u.lux.unit}@1m`);
  if (f.colour.cri) parts.push(`CRI ${f.colour.cri}`);
  return parts.join(' · ');
}
