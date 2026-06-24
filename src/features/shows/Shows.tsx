import { useRef, useState } from 'react';
import { Field, Select, TextInput, ToolCard, ToolPage } from '@/components/ui';
import { showRepo } from '@/db';
import { useShows } from '@/hooks/useShows';
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
  const [name, setName] = useState('');
  const [consoleType, setConsoleType] = useState<ConsoleType>('ma3');
  const [status, setStatus] = useState<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  const create = async () => {
    if (!name.trim()) return;
    await showRepo.create(newShowDraft(name.trim(), consoleType));
    setName('');
    setStatus(`Created “${name.trim()}”`);
  };

  const duplicate = async (id: ShowId, original: string) => {
    await showRepo.duplicate(id, `${original} (copy)`);
    setStatus(`Duplicated “${original}”`);
  };

  const remove = async (id: ShowId, label: string) => {
    if (!confirm(`Delete “${label}”? This cannot be undone.`)) return;
    await showRepo.delete(id);
    setStatus(`Deleted “${label}”`);
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
    setStatus(`Exported “${label}”`);
  };

  const onImportFile = async (file: File) => {
    try {
      const text = await file.text();
      const show = await importBundle(parseBundle(text));
      setStatus(`Imported “${show.name}”`);
    } catch (e) {
      setStatus(`Import failed: ${(e as Error).message}`);
    }
  };

  return (
    <ToolPage section={2} title="Shows" intro="Save, open, duplicate, export and import jobs. All stored on this device.">
      <ToolCard title="New show">
        <Field label="Name">
          <TextInput value={name} onChange={setName} placeholder="e.g. Studio 2 – Drama pilot" />
        </Field>
        <Field label="Console">
          <Select
            value={consoleType}
            onChange={setConsoleType}
            options={[
              { value: 'ma3', label: 'grandMA3' },
              { value: 'titan', label: 'Avolites Titan' },
            ]}
          />
        </Field>
        <button className="btn" onClick={create} disabled={!name.trim()}>Create show</button>
      </ToolCard>

      <ToolCard title={`Saved shows (${shows.length})`}>
        {shows.length === 0 && <p className="muted">No saved shows yet.</p>}
        <ul className="line-list">
          {shows.map((s) => (
            <li key={s.id} className="show-row">
              <span className="fixture-meta">
                <strong>{s.name}</strong>
                <span className="muted">
                  {s.console.type.toUpperCase()} · {s.patch.length} fixtures · saved {fmtDate(s.updatedAt)}
                </span>
              </span>
              <span className="chip-row">
                <button className="chip" onClick={() => duplicate(s.id, s.name)}>Duplicate</button>
                <button className="chip" onClick={() => exportShow(s.id, s.name)}>Export</button>
                <button className="chip" onClick={() => remove(s.id, s.name)}>Delete</button>
              </span>
            </li>
          ))}
        </ul>
      </ToolCard>

      <ToolCard title="Import">
        <p className="muted">Restore a show from a .slapp.json bundle exported on another device.</p>
        <input
          ref={fileInput}
          type="file"
          accept="application/json,.json"
          style={{ display: 'none' }}
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) void onImportFile(f);
            e.target.value = '';
          }}
        />
        <button className="btn" onClick={() => fileInput.current?.click()}>Choose bundle file…</button>
      </ToolCard>

      {status && <p className="status-line">{status}</p>}
    </ToolPage>
  );
}

function fmtDate(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString();
}
