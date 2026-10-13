import { useMemo, useRef, useState } from 'react';
import { EmptyState, Field, Select, ToolCard, ToolPage } from '@/components/ui';
import { FixtureSymbol } from '@/components/FixtureSymbol';
import { Icon } from '@/components/icons';
import { useFixtures } from '@/hooks/useLibrary';
import { useUnits } from '@/hooks/useUnits';
import { fixtureRepo } from '@/db';
import { parseGdtf } from '@/services/gdtf';
import {
  downloadFile,
  SYMBOL_LABELS,
  symbolFilename,
  symbolKindFor,
  symbolPng,
  symbolSvg,
  type SymbolKind,
} from '@/services/symbols';
import { DEFAULT_PHOTOMETRY_KEY, type Fixture, type FixtureMode } from '@/models/fixture';
import type { Units } from '@/services/units';

/**
 * Master–detail library: a searchable, type-filterable list on the left and a
 * sticky detail pane on the right (iPad and up). On phones the detail opens
 * inline under the tapped row instead.
 */
export function FixtureLibrary() {
  const fixtures = useFixtures();
  const u = useUnits();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [kind, setKind] = useState<SymbolKind | 'all'>('all');
  const [a, setA] = useState('');
  const [b, setB] = useState('');
  const [importStatus, setImportStatus] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const kinds = useMemo(() => {
    const counts = new Map<SymbolKind, number>();
    for (const f of fixtures) counts.set(symbolKindFor(f), (counts.get(symbolKindFor(f)) ?? 0) + 1);
    return [...counts.entries()].sort((x, y) => y[1] - x[1]);
  }, [fixtures]);

  const filtered = useMemo(() => {
    const terms = search.trim().toLowerCase().split(/\s+/).filter(Boolean);
    return fixtures.filter((f) => {
      if (kind !== 'all' && symbolKindFor(f) !== kind) return false;
      if (!terms.length) return true;
      const hay = `${f.manufacturer} ${f.model} ${f.category ?? ''}`.toLowerCase();
      return terms.every((t) => hay.includes(t));
    });
  }, [fixtures, search, kind]);

  const grouped = groupByManufacturer(filtered);
  const selected = fixtures.find((f) => f.id === selectedId) ?? null;
  const brandCount = useMemo(() => new Set(fixtures.map((f) => f.manufacturer)).size, [fixtures]);

  const handleGdtfImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files?.length) return;
    let imported = 0;
    const warnings: string[] = [];
    for (const file of Array.from(files)) {
      try {
        const result = parseGdtf(await file.arrayBuffer());
        await fixtureRepo.put(result.fixture);
        imported++;
        setSelectedId(result.fixture.id);
        warnings.push(...result.warnings.map((w) => `${file.name}: ${w}`));
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
    setSelectedId(null);
  };

  const compareWith = (fx: Fixture) => {
    if (!a || a === fx.id) setA(fx.id);
    else setB(fx.id);
    document.getElementById('comparator')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  const detail = (f: Fixture) => (
    <FixtureDetail fixture={f} u={u} onDelete={() => handleDelete(f)} onCompare={() => compareWith(f)} />
  );

  return (
    <ToolPage title="Fixture Library" intro={`${fixtures.length} fixtures across ${brandCount} brands — cached for offline use.`}>
      <div className="lib tool-card-wide">
        <div className="lib-list">
          <div className="lib-toolbar">
            <div className="fp-search">
              <Icon name="search" size={18} />
              <input
                type="search"
                className="input"
                value={search}
                placeholder="Search model, brand or type…"
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <div className="chip-row chip-scroll">
              <button className={`fp-tab${kind === 'all' ? ' fp-tab-active' : ''}`} onClick={() => setKind('all')}>
                All <span className="fp-tab-count">{fixtures.length}</span>
              </button>
              {kinds.map(([k, n]) => (
                <button key={k} className={`fp-tab${kind === k ? ' fp-tab-active' : ''}`} onClick={() => setKind(k)}>
                  <FixtureSymbol kind={k} size={16} /> {SYMBOL_LABELS[k]} <span className="fp-tab-count">{n}</span>
                </button>
              ))}
            </div>
            <div className="btn-row">
              <label className="btn btn-sm btn-secondary">
                <Icon name="upload" size={16} /> Import .gdtf
                <input ref={fileRef} type="file" accept=".gdtf,.zip" multiple hidden onChange={handleGdtfImport} />
              </label>
              <span className="muted small">Get exact profiles from gdtf-share.com</span>
            </div>
            {importStatus && <p className="status-line">{importStatus}</p>}
          </div>

          {grouped.length === 0 && (
            <EmptyState icon={<Icon name="search" size={28} />} title="No fixtures match">
              Try a model name like “Forza” or clear the type filter.
            </EmptyState>
          )}

          {grouped.map(([brand, list]) => (
            <section key={brand} className="lib-brand">
              <h3 className="lib-brand-name">
                {brand} <span className="muted">{list.length}</span>
              </h3>
              <ul className="fixture-list">
                {list.map((f) => {
                  const on = f.id === selectedId;
                  return (
                    <li key={f.id}>
                      <button
                        className={`fixture-row${on ? ' fixture-row-on' : ''}`}
                        onClick={() => setSelectedId(on ? null : f.id)}
                        aria-expanded={on}
                      >
                        <FixtureSymbol fixture={f} size={30} />
                        <span className="fixture-meta">
                          <strong>{f.model}</strong>
                          <span className="muted small">
                            {f.category} · {f.modes.length} mode{f.modes.length === 1 ? '' : 's'}
                            {summarise(f, u) && ` · ${summarise(f, u)}`}
                          </span>
                        </span>
                        {f.source.origin === 'gdtf-share' && <span className="badge">GDTF</span>}
                      </button>
                      {on && <div className="lib-inline">{detail(f)}</div>}
                    </li>
                  );
                })}
              </ul>
            </section>
          ))}
        </div>

        <aside className="lib-detail">
          {selected ? (
            detail(selected)
          ) : (
            <EmptyState icon={<FixtureSymbol kind="fresnel" size={44} />} title="Pick a fixture">
              Its DMX modes, channel chart, plot symbol and specs show here.
            </EmptyState>
          )}
        </aside>
      </div>

      <div id="comparator" className="tool-card-wide">
        <ToolCard title="Compare">
          <div className="row2">
            <Select value={a} onChange={setA} options={pickOptions(fixtures)} />
            <Select value={b} onChange={setB} options={pickOptions(fixtures)} />
          </div>
          {fxPair(fixtures, a, b) ? (
            <Comparator a={fxPair(fixtures, a, b)![0]} b={fxPair(fixtures, a, b)![1]} u={u} />
          ) : (
            <p className="muted small">Choose two fixtures, or tap “Compare” on a fixture’s detail.</p>
          )}
        </ToolCard>
      </div>
    </ToolPage>
  );
}

// --- Detail pane ------------------------------------------------------------

function FixtureDetail({
  fixture: f,
  u,
  onDelete,
  onCompare,
}: {
  fixture: Fixture;
  u: Units;
  onDelete: () => void;
  onCompare: () => void;
}) {
  const [modeName, setModeName] = useState(f.modes[0]?.name ?? '');
  const mode = f.modes.find((m) => m.name === modeName) ?? f.modes[0];
  const kind = symbolKindFor(f);

  const saveSvg = () =>
    downloadFile(symbolSvg(kind, { color: '#111111', label: f.model, size: 256 }), symbolFilename(f, 'svg'), 'image/svg+xml');
  const savePng = async () => downloadFile(await symbolPng(kind, { label: f.model, size: 512 }), symbolFilename(f, 'png'));

  return (
    <div className="fx-detail" key={f.id}>
      <header className="fx-detail-head">
        <div className="fx-detail-symbol">
          <FixtureSymbol fixture={f} size={60} />
        </div>
        <div>
          <p className="eyebrow">{f.manufacturer}</p>
          <h2 className="fx-detail-title">{f.model}</h2>
          <span className="muted small">
            {f.category} · {SYMBOL_LABELS[kind]} symbol{f.source.origin === 'gdtf-share' ? ' · GDTF profile' : ''}
          </span>
        </div>
      </header>

      <div className="spec-grid">
        <Spec label="Output @ 1 m" value={fmtLux(f, u)} unit={u.lux.unit} />
        <Spec label="Max power" value={maxPower(f)} unit="W" />
        <Spec label="Beam" value={beam(f)} unit="°" />
        <Spec
          label={f.colour.hasColourMixing ? 'CCT · full colour' : 'CCT'}
          value={cctText(f)}
          unit={f.colour.cctRange || f.colour.nativeCct ? 'K' : ''}
        />
        <Spec label="CRI / TLCI" value={`${f.colour.cri ?? '—'} / ${f.colour.tlci ?? '—'}`} />
        <Spec label="Weight" value={f.weightKg ? u.mass.format(f.weightKg) : '—'} unit={f.weightKg ? u.mass.unit : ''} />
      </div>

      {mode && (
        <>
          <Field label={`DMX mode · ${f.modes.length} available`} group>
            {f.modes.length > 6 ? (
              <Select
                value={mode.name}
                onChange={setModeName}
                options={f.modes.map((m) => ({ value: m.name, label: `${m.name} — ${m.channelCount} ch` }))}
              />
            ) : (
              <div className="mode-tabs">
                {f.modes.map((m) => (
                  <button
                    key={m.name}
                    className={`mode-tab${m.name === mode.name ? ' mode-tab-active' : ''}`}
                    onClick={() => setModeName(m.name)}
                  >
                    {m.name} · {m.channelCount}ch
                  </button>
                ))}
              </div>
            )}
          </Field>
          <div className="mode-summary">
            <span><strong>{mode.channelCount}</strong> ch footprint</span>
            {mode.powerW !== undefined && <span>{mode.powerW} W</span>}
            <span>{mode.channels.length} mapped</span>
            <span>{f.photometry[DEFAULT_PHOTOMETRY_KEY]?.dimmingCurve.type ?? 'linear'} dimming</span>
          </div>
          <div className="dmx-scroll">
            <DmxChart mode={mode} />
          </div>
        </>
      )}

      <div className="symbol-export">
        <FixtureSymbol fixture={f} size={44} label={f.model} />
        <div>
          <strong>Plot symbol</strong>
          <span className="muted small">For CAD plots, the Polycam plot or a console image pool.</span>
          <div className="btn-row">
            <button className="btn btn-sm btn-secondary" onClick={saveSvg}><Icon name="download" size={16} /> SVG</button>
            <button className="btn btn-sm btn-secondary" onClick={() => void savePng()}><Icon name="download" size={16} /> PNG</button>
          </div>
        </div>
      </div>

      <div className="btn-row">
        <button className="btn btn-sm btn-secondary" onClick={onCompare}>Compare</button>
        <button className="btn btn-sm btn-danger" onClick={onDelete}>Delete</button>
      </div>
    </div>
  );
}

function Spec({ label, value, unit }: { label: string; value: string | number; unit?: string }) {
  return (
    <div className="spec">
      <span className="spec-label">{label}</span>
      <span className="spec-value">
        {value}
        {unit && value !== '—' && <span className="spec-unit"> {unit}</span>}
      </span>
    </div>
  );
}

function DmxChart({ mode }: { mode: FixtureMode }) {
  if (mode.channels.length === 0) {
    return <p className="muted small" style={{ padding: 12 }}>No channel detail available for this mode.</p>;
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
            <td>{ch.offset + 1}{ch.resolution > 8 ? `–${ch.offset + ch.resolution / 8}` : ''}</td>
            <td>{ch.label}</td>
            <td><span className={`dmx-attr attr-${ch.attribute}`}>{ch.attribute}</span></td>
            <td className="muted">{ch.resolution}-bit</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

// --- Comparator ---------------------------------------------------------------

function Comparator({ a, b, u }: { a: Fixture; b: Fixture; u: Units }) {
  return (
    <table className="compare-table">
      <thead>
        <tr>
          <th />
          <th><FixtureSymbol fixture={a} size={22} /> {a.model}</th>
          <th><FixtureSymbol fixture={b} size={22} /> {b.model}</th>
        </tr>
      </thead>
      <tbody>
        <CompareRow label={`Output @ 1 m (${u.lux.unit})`} a={lux(a)} b={lux(b)} format={(v) => u.lux.format(v)} />
        <CompareRow label="Max power (W)" a={maxPower(a)} b={maxPower(b)} lowerIsBetter />
        <CompareRow label={`Weight (${u.mass.unit})`} a={a.weightKg ?? '—'} b={b.weightKg ?? '—'} format={(v) => u.mass.format(v)} lowerIsBetter />
        <CompareRow label="CRI" a={a.colour.cri ?? '—'} b={b.colour.cri ?? '—'} />
        <CompareRow label="TLCI" a={a.colour.tlci ?? '—'} b={b.colour.tlci ?? '—'} />
        <CompareRow label="Beam angle (°)" a={beam(a)} b={beam(b)} neutral />
        <CompareRow label="DMX modes" a={a.modes.length} b={b.modes.length} />
      </tbody>
    </table>
  );
}

function CompareRow({
  label,
  a,
  b,
  format,
  lowerIsBetter,
  neutral,
}: {
  label: string;
  a: number | string;
  b: number | string;
  format?: (v: number) => string;
  lowerIsBetter?: boolean;
  neutral?: boolean;
}) {
  let better: 'a' | 'b' | null = null;
  if (!neutral && typeof a === 'number' && typeof b === 'number' && a !== b) {
    better = (a > b) !== !!lowerIsBetter ? 'a' : 'b';
  }
  const show = (v: number | string) => (typeof v === 'number' && format ? format(v) : v);
  return (
    <tr>
      <td className="muted">{label}</td>
      <td className={better === 'a' ? 'compare-best' : ''}>{show(a)}</td>
      <td className={better === 'b' ? 'compare-best' : ''}>{show(b)}</td>
    </tr>
  );
}

// --- Helpers --------------------------------------------------------------------

function groupByManufacturer(fixtures: Fixture[]): [string, Fixture[]][] {
  const map = new Map<string, Fixture[]>();
  for (const f of fixtures) {
    const list = map.get(f.manufacturer) ?? [];
    list.push(f);
    map.set(f.manufacturer, list);
  }
  return [...map.entries()].sort(([x], [y]) => x.localeCompare(y));
}

const fxPair = (fixtures: Fixture[], a: string, b: string): [Fixture, Fixture] | null => {
  const fa = fixtures.find((f) => f.id === a);
  const fb = fixtures.find((f) => f.id === b);
  return fa && fb ? [fa, fb] : null;
};

const pickOptions = (fixtures: Fixture[]) => [
  { value: '', label: 'Select a fixture…' },
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
const cctText = (f: Fixture): string =>
  f.colour.cctRange
    ? `${f.colour.cctRange.minK.toLocaleString()}–${f.colour.cctRange.maxK.toLocaleString()}`
    : f.colour.nativeCct
      ? String(f.colour.nativeCct)
      : f.colour.hasColourMixing
        ? 'RGB'
        : '—';

function summarise(f: Fixture, u: Units): string {
  const l = f.photometry[DEFAULT_PHOTOMETRY_KEY]?.luxAt1m;
  return l ? `${u.lux.format(l)} ${u.lux.unit}@1m` : '';
}
