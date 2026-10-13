import { useRef, useState } from 'react';
import { EmptyState, Field, TextInput, ToolCard, ToolPage } from '@/components/ui';
import { Icon } from '@/components/icons';
import { showRepo } from '@/db';
import { useShows } from '@/hooks/useShows';
import { useActiveShow } from '@/hooks/useActiveShow';
import {
  bundleToJson,
  exportBundle,
  importBundle,
  newShowDraft,
  parseBundle,
} from '@/services/show';
import type { ConsoleType } from '@/models/console';
import type { ShowId } from '@/models/common';

export function Shows() {
  const shows = useShows();
  const { show: activeShow, setActiveShow } = useActiveShow();
  const [name, setName] = useState('');
  const [consoleType, setConsoleType] = useState<ConsoleType>('ma3');
  const [status, setStatus] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const create = async () => {
    if (!name.trim()) return;
    const show = await showRepo.create(newShowDraft(name.trim(), consoleType));
    await setActiveShow(show.id);
    setName('');
    setStatus(`Created "${name.trim()}" and set as active`);
  };

  const duplicate = async (id: ShowId, original: string) => {
    await showRepo.duplicate(id, `${original} (copy)`);
    setStatus(`Duplicated "${original}"`);
  };

  const remove = async (id: ShowId, label: string) => {
    if (!confirm(`Delete "${label}"? This cannot be undone.`)) return;
    if (activeShow?.id === id) await setActiveShow(undefined);
    await showRepo.delete(id);
    setStatus(`Deleted "${label}"`);
  };

  const exportShow = async (id: ShowId, label: string) => {
    const bundle = await exportBundle(id);
    const blob = new Blob([bundleToJson(bundle)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${label.replace(/[^a-z0-9]+/gi, '-').toLowerCase()}.slapp.json`;
    a.click();
    URL.revokeObjectURL(url);
    setStatus(`Exported "${label}"`);
  };

  const onImportFile = async (file: File) => {
    try {
      const text = await file.text();
      const show = await importBundle(parseBundle(text));
      setStatus(`Imported "${show.name}"`);
    } catch (e) {
      setStatus(`Import failed: ${(e as Error).message}`);
    }
  };

  return (
    <ToolPage section={2} title="Shows" intro="One show per job. Everything is stored on this device — export a bundle to move it to another.">
      <ToolCard title="New show">
        <Field label="Name">
          <TextInput value={name} onChange={setName} placeholder="e.g. Studio 2 – Drama pilot" />
        </Field>
        <Field label="Console" group>
          <div className="segmented">
            {(['ma3', 'titan'] as const).map((c) => (
              <button key={c} className={consoleType === c ? 'on' : ''} onClick={() => setConsoleType(c)}>
                {c === 'ma3' ? 'grandMA3' : 'Avolites Titan'}
              </button>
            ))}
          </div>
        </Field>
        <button className="btn" onClick={create} disabled={!name.trim()}>
          <Icon name="shows" size={18} /> Create &amp; open
        </button>
      </ToolCard>

      <ToolCard title="Import a show">
        <label className="dropzone">
          <Icon name="upload" size={26} />
          <strong>Choose a .slapp.json bundle</strong>
          <span className="muted small">Exported from Shows on another iPad or phone — patch, plot and fixtures come with it.</span>
          <input
            ref={fileInput}
            type="file"
            accept="application/json,.json"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void onImportFile(f);
              e.target.value = '';
            }}
          />
        </label>
      </ToolCard>

      <ToolCard title={`Saved shows · ${shows.length}`} wide>
        {status && <p className="status-line" style={{ margin: 0 }}>{status}</p>}
        {shows.length === 0 ? (
          <EmptyState icon={<Icon name="shows" size={28} />} title="No shows yet">
            Create one above — it becomes your active show straight away.
          </EmptyState>
        ) : (
          <ul className="show-list">
            {shows.map((s) => {
              const on = activeShow?.id === s.id;
              return (
                <li key={s.id} className={`show-card${on ? ' show-card-on' : ''}`}>
                  <div className="show-card-main">
                    <strong>{s.name}</strong>
                    <span className="muted small">
                      {s.console.type === 'titan' ? 'Avolites Titan' : 'grandMA3'} · {s.patch.length} fixture{s.patch.length === 1 ? '' : 's'}
                      {s.plot ? ` · plot (${s.plot.tags.length} tags)` : ''} · {fmtDate(s.updatedAt)}
                    </span>
                  </div>
                  <div className="btn-row">
                    {on ? (
                      <span className="badge badge-on">Active</span>
                    ) : (
                      <button className="btn btn-sm" onClick={() => void setActiveShow(s.id)}>Open</button>
                    )}
                    <button className="btn btn-sm btn-ghost" onClick={() => duplicate(s.id, s.name)}>Duplicate</button>
                    <button className="btn btn-sm btn-ghost" onClick={() => exportShow(s.id, s.name)}>
                      <Icon name="download" size={16} /> Export
                    </button>
                    <button className="btn btn-sm btn-ghost btn-danger-text" onClick={() => remove(s.id, s.name)}>Delete</button>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </ToolCard>

    </ToolPage>
  );
}

function fmtDate(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString();
}
