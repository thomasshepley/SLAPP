import { useMemo, useState } from 'react';
import { Field, NumberInput, Select, TextInput, ToolCard, ToolPage } from '@/components/ui';
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
      <ToolCard title="Universes">
        <p className="muted" style={{ fontSize: '0.85rem' }}>Set each universe as wireless or copper (sACN/Art-Net).</p>
        <table className="dmx-table">
          <thead>
            <tr><th>Univ</th><th>Transport</th><th>Note</th></tr>
          </thead>
          <tbody>
            {universeConfig.map((u, i) => (
              <tr key={u.universe}>
                <td>{u.universe}</td>
                <td>
                  <Select
                    value={u.transport}
                    onChange={(v) => updateTransport(i, v as 'wireless' | 'copper')}
                    options={[
                      { value: 'copper', label: 'Copper' },
                      { value: 'wireless', label: 'Wireless' },
                    ]}
                  />
                </td>
                <td className="muted">{u.note ?? ''}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </ToolCard>

      <ToolCard title="Add fixtures">
        <Field label="Fixture type">
          <FixturePicker
            value={pick}
            onChange={(id, fx) => {
              setPick(id);
              setMode(fx?.modes[0]?.name ?? '');
            }}
          />
        </Field>
        {picked && (
          <Field label="Mode">
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
        <button className="btn" onClick={addLine} disabled={!picked}>Add to list</button>
      </ToolCard>

      {lines.length > 0 && (
        <ToolCard title="Fixture list">
          <ul className="line-list">
            {lines.map((l) => (
              <li key={l.key} className="line-row">
                <span>{l.quantity} × {nameOf(l.fixtureId)} <span className="muted">[{l.mode}]</span></span>
                <button className="chip" onClick={() => setLines(lines.filter((x) => x.key !== l.key))}>×</button>
              </li>
            ))}
          </ul>
        </ToolCard>
      )}

      {result.items.length > 0 && (
        <>
          <ToolCard title="Patch preview">
            {result.overflows.length > 0 && (
              <p className="status-line" style={{ color: '#ff5c5c' }}>
                Universe overflow — {result.overflows.reduce((s, o) => s + o.excessChannels, 0)} channels didn't fit. Add universes to the profile.
              </p>
            )}
            <PatchTable items={result.items} nameOf={nameOf} fixtures={fxMap} universes={universeConfig} />
          </ToolCard>

          <ToolCard title="Save / export">
            <Field label="Save patch into show">
              <Select<string>
                value=""
                onChange={(v) => v && void saveToShow(v as ShowId)}
                options={[
                  {
                    value: '',
                    label: shows.length
                      ? activeShow
                        ? `Save to "${activeShow.name}"…`
                        : 'Choose a show…'
                      : 'No saved shows yet',
                  },
                  ...(activeShow ? [{ value: activeShow.id as string, label: `${activeShow.name} (active)` }] : []),
                  ...shows.filter((s) => s.id !== activeShow?.id).map((s) => ({ value: s.id as string, label: s.name })),
                ]}
              />
            </Field>
            <button className="btn" onClick={() => window.print()}>Print cheat sheet</button>
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
        <tr><th>Label</th><th>Fixture</th><th>Mode</th><th>Univ</th><th>Transport</th><th>Addr</th></tr>
      </thead>
      <tbody>
        {items.map((it) => {
          const uni = universes.find((u) => u.universe === it.universe);
          return (
            <tr key={it.id}>
              <td>{it.label}</td>
              <td>{nameOf(it.fixtureId)}</td>
              <td className="muted">{fixtures.get(it.fixtureId)?.modes.find((m) => m.name === it.mode)?.channelCount ?? '?'}ch</td>
              <td>{it.universe}</td>
              <td className="muted">{uni?.transport ?? '—'}</td>
              <td>{it.startAddress}</td>
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
              <td>{it.startAddress}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
