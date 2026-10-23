import { useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { strToU8, zipSync } from 'fflate';
import { EmptyState, Field, NumberInput, Select, ToolCard, ToolPage } from '@/components/ui';
import { FixtureSymbol } from '@/components/FixtureSymbol';
import { Icon } from '@/components/icons';
import { useFixtures } from '@/hooks/useLibrary';
import { useShows } from '@/hooks/useShows';
import { useActiveShow } from '@/hooks/useActiveShow';
import {
  buildExportRows,
  dotted,
  fidRanges,
  toCsv,
  toMa3Macro,
  typeBlocks,
} from '@/services/console/export';
import { downloadFile, symbolFilename, symbolKindFor, symbolPng, symbolSvg } from '@/services/symbols';
import type { ConsoleType } from '@/models/console';
import type { FixtureId } from '@/models/common';

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'show';

export function ConsoleExport() {
  const fixtures = useFixtures();
  const shows = useShows();
  const { show: active } = useActiveShow();
  const [showId, setShowId] = useState<string>('');
  const [target, setTarget] = useState<ConsoleType | ''>('');
  const [startFid, setStartFid] = useState<number | ''>(101);
  const [copied, setCopied] = useState(false);
  const [busy, setBusy] = useState(false);

  const show = shows.find((s) => s.id === showId) ?? active ?? shows[0] ?? null;
  const desk = target || show?.console.type || 'ma3';
  const fxMap = useMemo(() => new Map(fixtures.map((f) => [f.id, f])), [fixtures]);
  const rows = useMemo(
    () => (show ? buildExportRows(show.patch, fxMap, typeof startFid === 'number' ? startFid : 101) : []),
    [show, fxMap, startFid],
  );
  const blocks = useMemo(() => typeBlocks(rows), [rows]);
  const macro = show ? toMa3Macro(rows, show.name) : '';
  const universes = new Set(rows.map((r) => r.universe)).size;

  if (!shows.length) {
    return (
      <ToolPage title="Console Export" intro="Send a show’s patch to grandMA3 or Avolites Titan.">
        <div className="tool-card-wide">
          <EmptyState icon={<Icon name="shows" size={30} />} title="No shows yet">
            Create a show and build its patch, then export it here.{' '}
            <Link to="/f/shows">Create a show →</Link>
          </EmptyState>
        </div>
      </ToolPage>
    );
  }

  const copyMacro = async () => {
    await navigator.clipboard.writeText(macro);
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  };

  const symbolPack = async () => {
    if (!show) return;
    setBusy(true);
    try {
      const files: Record<string, Uint8Array> = {};
      const ids = [...new Set(show.patch.map((p) => p.fixtureId))];
      for (const id of ids) {
        const f = fxMap.get(id as FixtureId);
        if (!f) continue;
        const kind = symbolKindFor(f);
        files[`svg/${symbolFilename(f, 'svg')}`] = strToU8(symbolSvg(kind, { color: '#111111', label: f.model, size: 256 }));
        const png = await symbolPng(kind, { label: f.model, size: 512 });
        files[`png/${symbolFilename(f, 'png')}`] = new Uint8Array(await png.arrayBuffer());
      }
      files['patch.csv'] = strToU8(toCsv(rows));
      const zip = zipSync(files);
      downloadFile(new Blob([zip], { type: 'application/zip' }), `${slug(show.name)}-console-pack.zip`);
    } finally {
      setBusy(false);
    }
  };

  return (
    <ToolPage title="Console Export" intro="Take a show’s patch to the desk — as an MA3 address macro, a CSV, a patch sheet and plot symbols.">
      <ToolCard title="Show & console">
        <Field label="Show">
          <Select
            value={show?.id ?? ''}
            onChange={setShowId}
            options={shows.map((s) => ({
              value: s.id,
              label: `${s.name}${s.id === active?.id ? ' (active)' : ''} — ${s.patch.length} fixtures`,
            }))}
          />
        </Field>
        <Field label="Console" group>
          <div className="segmented">
            {(['ma3', 'titan'] as const).map((c) => (
              <button key={c} className={desk === c ? 'on' : ''} onClick={() => setTarget(c)}>
                {c === 'ma3' ? 'grandMA3' : 'Avolites Titan'}
              </button>
            ))}
          </div>
        </Field>
        <Field label="First fixture ID" hint="Fixtures are numbered in universe / address order">
          <NumberInput value={startFid} onChange={setStartFid} min={1} />
        </Field>
      </ToolCard>

      <ToolCard title="Export">
        <div className="hero-stats">
          <span className="stat"><strong>{rows.length}</strong><span>fixtures</span></span>
          <span className="stat"><strong>{blocks.length}</strong><span>types</span></span>
          <span className="stat"><strong>{universes}</strong><span>universes</span></span>
        </div>
        {rows.length === 0 ? (
          <EmptyState icon={<Icon name="showfile" size={28} />} title="This show has no patch yet">
            <Link to="/f/showfile">Build one in New Showfile →</Link>
          </EmptyState>
        ) : (
          <div className="export-actions">
            <button className="btn" onClick={() => downloadFile(toCsv(rows), `${slug(show!.name)}-patch.csv`, 'text/csv')}>
              <Icon name="download" size={18} /> Patch CSV
            </button>
            <button className="btn btn-secondary" disabled={busy} onClick={() => void symbolPack()}>
              <Icon name="download" size={18} /> {busy ? 'Building…' : 'Console pack (.zip)'}
            </button>
            <button className="btn btn-secondary" onClick={() => window.print()}>
              <Icon name="showfile" size={18} /> Print patch sheet
            </button>
            <p className="muted small">
              The pack holds the CSV plus SVG and PNG plot symbols for every fixture type — ready for an image pool or a CAD plot.
            </p>
          </div>
        )}
      </ToolCard>

      {rows.length > 0 && desk === 'ma3' && (
        <ToolCard
          title="grandMA3 address macro"
          wide
          aside={
            <div className="btn-row">
              <button className="btn btn-sm btn-secondary" onClick={() => void copyMacro()}>
                <Icon name={copied ? 'check' : 'copy'} size={16} /> {copied ? 'Copied' : 'Copy'}
              </button>
              <button className="btn btn-sm btn-secondary" onClick={() => downloadFile(macro, `${slug(show!.name)}-ma3-patch.txt`)}>
                <Icon name="download" size={16} /> .txt
              </button>
            </div>
          }
        >
          <ol className="steps">
            <li>In <strong>Patch</strong>, add each fixture type below with its FIDs and mode.</li>
            <li>Paste the lines into the command line (or a macro) — every address is set in one go.</li>
          </ol>
          <TypeBlocks blocks={blocks} />
          <pre className="code-block">{macro}</pre>
        </ToolCard>
      )}

      {rows.length > 0 && desk === 'titan' && (
        <ToolCard title="Avolites Titan" wide>
          <ol className="steps">
            <li>Titan has no patch-file import, so patch from this sheet: <strong>Patch → Fixture</strong>, pick the type and mode, set the user number and address.</li>
            <li>Each block below is one patch pass — same type, consecutive user numbers.</li>
          </ol>
          <TypeBlocks blocks={blocks} titan />
        </ToolCard>
      )}

      {rows.length > 0 && (
        <ToolCard title="Patch sheet" wide>
          <div className="table-scroll">
            <table className="stops-table patch-sheet">
              <thead>
                <tr><th>FID</th><th>Label</th><th>Fixture</th><th>Mode</th><th>Footprint</th><th>Univ.Addr</th></tr>
              </thead>
              <tbody>
                {rows.map((r) => {
                  const fx = fxMap.get(r.fixtureId);
                  return (
                    <tr key={`${r.fid}`}>
                      <td><strong>{r.fid}</strong></td>
                      <td>{r.label}</td>
                      <td className="cell-fixture">{fx && <FixtureSymbol fixture={fx} size={20} />} {r.manufacturer} {r.model}</td>
                      <td className="muted">{r.mode}</td>
                      <td className="muted">{r.footprint} ch</td>
                      <td><span className="addr">{dotted(r)}</span></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </ToolCard>
      )}

      {rows.length > 0 && (
        <div className="print-only cheat-sheet">
          <h1>{show!.name} — patch sheet</h1>
          <p>{rows.length} fixtures · {desk === 'ma3' ? 'grandMA3' : 'Avolites Titan'} · {new Date().toLocaleString()}</p>
          <table>
            <thead><tr><th>FID</th><th>Label</th><th>Fixture</th><th>Mode</th><th>Ch</th><th>Univ.Addr</th></tr></thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.fid}><td>{r.fid}</td><td>{r.label}</td><td>{r.manufacturer} {r.model}</td><td>{r.mode}</td><td>{r.footprint}</td><td>{dotted(r)}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <ToolCard title="Live link" wide>
        <p className="muted small" style={{ margin: 0 }}>
          A direct network connection to the desk (pulling levels, pushing the patch) needs the console’s
          remote API on the lighting network and is not available yet. Exports above work fully offline.
        </p>
      </ToolCard>
    </ToolPage>
  );
}

function TypeBlocks({ blocks, titan }: { blocks: ReturnType<typeof typeBlocks>; titan?: boolean }) {
  return (
    <ul className="type-blocks">
      {blocks.map((b) => (
        <li key={b.key}>
          <span className="type-count">{b.fids.length}×</span>
          <span className="type-name">
            <strong>{b.manufacturer} {b.model}</strong>
            <span className="muted small">{b.mode}</span>
          </span>
          <span className="type-fids">{titan ? 'User #' : 'FID'} {fidRanges(b.fids)}</span>
        </li>
      ))}
    </ul>
  );
}
