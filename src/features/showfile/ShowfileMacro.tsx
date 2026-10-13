import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { EmptyState, Field, NumberInput, Select, TextInput, ToolCard, ToolPage } from '@/components/ui';
import { FixtureSymbol } from '@/components/FixtureSymbol';
import { Icon } from '@/components/icons';
import { FixturePicker } from '@/components/FixturePicker';
import { useFixtures } from '@/hooks/useLibrary';
import { useShows } from '@/hooks/useShows';
import { useActiveShow } from '@/hooks/useActiveShow';
import { showRepo } from '@/db';
import { defaultUniverseProfile } from '@/services/show';
import { packPatch, type PackRequest } from '@/services/patch/packer';
import type { Fixture } from '@/models/fixture';
import type { FixtureId, ShowId } from '@/models/common';
import type { UniverseAssignment } from '@/models/patch';

interface DraftLine extends PackRequest {
  key: string;
}

export function ShowfileMacro() {
  const fixtures = useFixtures();
  const shows = useShows();
  const { show: activeShow } = useActiveShow();
  const [lines, setLines] = useState<DraftLine[]>([]);
  const [status, setStatus] = useState<string | null>(null);
  const [added, setAdded] = useState<string | null>(null);

  const [pick, setPick] = useState<FixtureId | ''>('');
  const [mode, setMode] = useState('');
  const [qty, setQty] = useState<number | ''>(4);
  const [label, setLabel] = useState('');

  const [universeConfig, setUniverseConfig] = useState<UniverseAssignment[]>(() =>
    defaultUniverseProfile().universes,
  );

  const picked = fixtures.find((f) => f.id === pick);
  const fxMap = useMemo(() => new Map(fixtures.map((f) => [f.id, f])), [fixtures]);

  const profile = useMemo(
    () => ({ name: 'Custom', universes: universeConfig }),
    [universeConfig],
  );

  const result = useMemo(
    () => packPatch(lines, profile, fxMap),
    [lines, profile, fxMap],
  );

  const addLine = () => {
    if (!picked) return;
    const modeName = mode || picked.modes[0]?.name || '';
    setLines([
      ...lines,
      {
        key: crypto.randomUUID(),
        fixtureId: picked.id,
        mode: modeName,
        quantity: typeof qty === 'number' ? qty : 1,
        labelPrefix: label.trim() || picked.model,
      },
    ]);
    // Ready for the next type — the fixture list below confirms what went in.
    setAdded(`Added ${typeof qty === 'number' ? qty : 1} × ${picked.model}`);
    setPick('');
    setMode('');
    setLabel('');
  };

  const saveToShow = async (showId: ShowId) => {
    const show = await showRepo.get(showId);
    if (!show) return;
    show.patch = result.items;
    show.universeProfile = profile;
    await showRepo.save(show);
    setStatus(`Saved ${result.items.length} fixtures to "${show.name}"`);
  };

  const nameOf = (id: FixtureId) => {
    const f = fxMap.get(id);
    return f ? `${f.manufacturer} ${f.model}` : id;
  };

  const updateTransport = (idx: number, transport: 'wireless' | 'copper') => {
    setUniverseConfig(universeConfig.map((u, i) => (i === idx ? { ...u, transport } : u)));
  };

  return (
    <ToolPage
      section={4}
      title="New Showfile"
      intro="Build a fixture list, auto-pack addresses across universes, then save to a show or print a cheat sheet."
    >
      <ToolCard title="Add fixtures">
        <Field label="Fixture type" group>
          <FixturePicker
            value={pick}
            onChange={(id, fx) => {
              setPick(id);
              setMode(fx?.modes[0]?.name ?? '');
            }}
          />
        </Field>
        {picked && (
          <Field label={`Mode · ${picked.modes.length} available`}>
            <Select
              value={mode}
              onChange={setMode}
              options={picked.modes.map((m) => ({ value: m.name, label: `${m.name} (${m.channelCount}ch)` }))}
            />
          </Field>
        )}
        <div className="row2">
          <Field label="Quantity"><NumberInput value={qty} onChange={setQty} min={1} /></Field>
          <Field label="Label prefix"><TextInput value={label} onChange={setLabel} placeholder={picked?.model ?? 'e.g. Key'} /></Field>
        </div>
        <button className="btn" onClick={addLine} disabled={!picked}>
          {picked ? `Add ${typeof qty === 'number' ? qty : 1} × ${picked.model}` : 'Pick a fixture to add'}
        </button>
      </ToolCard>

      <ToolCard title={`Fixture list${lines.length ? ` · ${lines.reduce((n, l) => n + l.quantity, 0)} units` : ''}`}>
        {lines.length === 0 ? (
          <EmptyState icon={<Icon name="fixtures" size={28} />} title="Nothing added yet">
            Pick a fixture type, set a quantity and label, then add it. Addresses pack automatically.
          </EmptyState>
        ) : (
          <ul className="line-list">
            {lines.map((l) => {
              const fx = fxMap.get(l.fixtureId);
              const ch = fx?.modes.find((m) => m.name === l.mode)?.channelCount ?? 0;
              return (
                <li key={l.key} className="line-row">
                  {fx && <FixtureSymbol fixture={fx} size={24} />}
                  <span className="line-main">
                    <strong>{l.quantity} × {nameOf(l.fixtureId)}</strong>
                    <span className="muted small">{l.labelPrefix} · {l.mode} · {ch * l.quantity} ch</span>
                  </span>
                  <button className="chip" aria-label="Remove" onClick={() => setLines(lines.filter((x) => x.key !== l.key))}>×</button>
                </li>
              );
            })}
          </ul>
        )}
        {added && <p className="status-line">{added}</p>}
      </ToolCard>

      <ToolCard title="Universes" wide>
        <p className="muted small" style={{ margin: 0 }}>
          Tap a universe to switch it between copper and wireless DMX. Usage updates as you add fixtures.
        </p>
        <div className="uni-grid">
          {universeConfig.map((u, i) => {
            const used = result.items.filter((it) => it.universe === u.universe).reduce((n, it) => n + it.footprint, 0);
            return (
              <button
                key={u.universe}
                className={`uni-tile uni-${u.transport}`}
                onClick={() => updateTransport(i, u.transport === 'copper' ? 'wireless' : 'copper')}
              >
                <span className="uni-num">U{u.universe}</span>
                <span className="uni-kind">{u.transport === 'copper' ? 'Copper' : 'Wireless'}</span>
                <span className="uni-bar"><span style={{ width: `${Math.min(100, (used / 512) * 100)}%` }} /></span>
                <span className="uni-used">{used}/512</span>
              </button>
            );
          })}
        </div>
      </ToolCard>

      {result.items.length > 0 && (
        <>
          <ToolCard title="Patch preview" wide>
            {result.overflows.length > 0 && (
              <p className="status-line" style={{ color: '#ff5c5c' }}>
                Universe overflow — {result.overflows.reduce((s, o) => s + o.excessChannels, 0)} channels didn't fit. Add universes to the profile.
              </p>
            )}
            <div className="table-scroll">
              <PatchTable items={result.items} nameOf={nameOf} fixtures={fxMap} universes={universeConfig} />
            </div>
          </ToolCard>

          <ToolCard title="Save & export">
            {activeShow ? (
              <button className="btn" onClick={() => void saveToShow(activeShow.id)}>
                <Icon name="check" size={18} /> Save {result.items.length} fixtures to “{activeShow.name}”
              </button>
            ) : (
              <p className="muted small" style={{ margin: 0 }}>
                No active show — <Link to="/f/shows">create one</Link> or pick a saved show below.
              </p>
            )}
            {shows.some((s) => s.id !== activeShow?.id) && (
              <Field label="Or save into another show">
                <Select<string>
                  value=""
                  onChange={(v) => v && void saveToShow(v as ShowId)}
                  options={[
                    { value: '', label: 'Choose a show…' },
                    ...shows.filter((s) => s.id !== activeShow?.id).map((s) => ({ value: s.id as string, label: s.name })),
                  ]}
                />
              </Field>
            )}
            <div className="btn-row">
              <button className="btn btn-sm btn-secondary" onClick={() => window.print()}>
                <Icon name="showfile" size={16} /> Print cheat sheet
              </button>
              <Link className="btn btn-sm btn-secondary" to="/f/console">
                <Icon name="console" size={16} /> Export to console
              </Link>
            </div>
            {status && <p className="status-line">{status}</p>}
          </ToolCard>

          <CheatSheet items={result.items} nameOf={nameOf} fixtures={fxMap} />
        </>
      )}
    </ToolPage>
  );
}

function PatchTable({
  items,
  nameOf,
  fixtures,
  universes,
}: {
  items: ReturnType<typeof packPatch>['items'];
  nameOf: (id: FixtureId) => string;
  fixtures: Map<FixtureId, Fixture>;
  universes: UniverseAssignment[];
}) {
  return (
    <table className="stops-table">
      <thead>
        <tr><th>Label</th><th>Fixture</th><th>Mode</th><th>Univ</th><th>Transport</th><th>Univ.Addr</th></tr>
      </thead>
      <tbody>
        {items.map((it) => {
          const uni = universes.find((u) => u.universe === it.universe);
          return (
            <tr key={it.id}>
              <td>{it.label}</td>
              <td className="cell-fixture">
                {fixtures.get(it.fixtureId) && <FixtureSymbol fixture={fixtures.get(it.fixtureId)!} size={20} />}
                {nameOf(it.fixtureId)}
              </td>
              <td className="muted">{it.mode} · {it.footprint}ch</td>
              <td>{it.universe}</td>
              <td className="muted">{uni?.transport ?? '—'}</td>
              <td><span className="addr">{it.universe}.{it.startAddress}</span></td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}

function CheatSheet({
  items,
  nameOf,
  fixtures,
}: {
  items: ReturnType<typeof packPatch>['items'];
  nameOf: (id: FixtureId) => string;
  fixtures: Map<FixtureId, Fixture>;
}) {
  return (
    <div className="print-only cheat-sheet">
      <h1>Patch cheat sheet</h1>
      <p>{items.length} fixtures · generated {new Date().toLocaleString()}</p>
      <table>
        <thead>
          <tr><th>Label</th><th>Fixture</th><th>Mode (ch)</th><th>Universe</th><th>Start address</th></tr>
        </thead>
        <tbody>
          {items.map((it) => (
            <tr key={it.id}>
              <td>{it.label}</td>
              <td>{nameOf(it.fixtureId)}</td>
              <td>{it.mode} ({fixtures.get(it.fixtureId)?.modes.find((m) => m.name === it.mode)?.channelCount}ch)</td>
              <td>{it.universe}</td>
              <td><span className="addr">{it.universe}.{it.startAddress}</span></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
