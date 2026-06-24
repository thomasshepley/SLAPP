import { useRef, useState } from 'react';
import { Field, Select, TextInput, ToolCard, ToolPage } from '@/components/ui';
import { useFixtures } from '@/hooks/useLibrary';
import { useShows } from '@/hooks/useShows';
import { fileRepo, showRepo } from '@/db';
import { loadPdf } from '@/services/pdf/render';
import { newId, type PlotTagId, type ShowId } from '@/models/common';
import type { PlotTag } from '@/models/plot';

export function PlotImport() {
  const fixtures = useFixtures();
  const shows = useShows();
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [tags, setTags] = useState<PlotTag[]>([]);
  const [pdfBytes, setPdfBytes] = useState<ArrayBuffer | null>(null);
  const [pdfName, setPdfName] = useState('');
  const [pageCount, setPageCount] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [canvasSize, setCanvasSize] = useState({ width: 0, height: 0 });

  const onFile = async (file: File) => {
    setError(null);
    setTags([]);
    try {
      const bytes = await file.arrayBuffer();
      setPdfBytes(bytes);
      setPdfName(file.name);
      const pdf = await loadPdf(bytes.slice(0));
      setPageCount(pdf.pageCount);
      const canvas = canvasRef.current;
      if (canvas) {
        const width = Math.min(canvas.parentElement?.clientWidth ?? 600, 600);
        const size = await pdf.renderPage(1, canvas, width);
        setCanvasSize(size);
      }
      pdf.destroy();
    } catch (e) {
      setError(`Couldn't render PDF: ${(e as Error).message}. The file is still saved with the show.`);
    }
  };

  const onCanvasTap = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    const y = (e.clientY - rect.top) / rect.height;
    setTags([...tags, { id: newId<PlotTagId>(), page: 0, x, y, label: `Tag ${tags.length + 1}` }]);
  };

  const updateTag = (id: PlotTagId, patch: Partial<PlotTag>) =>
    setTags(tags.map((t) => (t.id === id ? { ...t, ...patch } : t)));

  const saveToShow = async (showId: ShowId) => {
    if (!pdfBytes) return;
    const show = await showRepo.get(showId);
    if (!show) return;
    const blob = new Blob([pdfBytes], { type: 'application/pdf' });
    const ref = await fileRepo.store(blob, 'polycam-pdf', pdfName);
    show.plot = { pdf: ref, pageCount: pageCount || 1, tags };
    await showRepo.save(show);
    setStatus(`Saved plot + ${tags.length} tags to “${show.name}”`);
  };

  return (
    <ToolPage
      section={6}
      title="Polycam Plot"
      intro="Import a Polycam PDF, then tap the plan to tag fixtures. Tagging is manual (visual PDF, not structured data) — tags are stored with the show and reusable."
    >
      <ToolCard title="Import">
        <input
          type="file"
          accept="application/pdf,.pdf"
          className="input"
          onChange={(e) => {
            const f = e.target.files?.[0];
            if (f) void onFile(f);
          }}
        />
        {pdfName && <p className="muted">{pdfName}{pageCount ? ` · ${pageCount} page(s)` : ''}</p>}
        {error && <p className="status-line" style={{ color: '#ff5c5c' }}>{error}</p>}
      </ToolCard>

      {pdfBytes && (
        <ToolCard title="Tag fixtures">
          <p className="muted">Tap the plan to drop a tag.</p>
          <div className="plot-wrap" style={{ position: 'relative', width: canvasSize.width || '100%' }}>
            <canvas ref={canvasRef} onClick={onCanvasTap} className="plot-canvas" />
            {tags.map((t) => (
              <span
                key={t.id}
                className="plot-tag"
                style={{ left: `${t.x * 100}%`, top: `${t.y * 100}%` }}
                title={t.label}
              >
                {t.label}
              </span>
            ))}
          </div>
        </ToolCard>
      )}

      {tags.length > 0 && (
        <ToolCard title={`Tags (${tags.length})`}>
          <ul className="line-list">
            {tags.map((t) => (
              <li key={t.id} className="tag-edit">
                <TextInput value={t.label} onChange={(v) => updateTag(t.id, { label: v })} />
                <Select
                  value={t.fixtureId ?? ''}
                  onChange={(v) => updateTag(t.id, { fixtureId: (v || undefined) as PlotTag['fixtureId'] })}
                  options={[
                    { value: '', label: 'Unassigned' },
                    ...fixtures.map((f) => ({ value: f.id as string, label: `${f.manufacturer} ${f.model}` })),
                  ]}
                />
                <button className="chip" onClick={() => setTags(tags.filter((x) => x.id !== t.id))}>×</button>
              </li>
            ))}
          </ul>
        </ToolCard>
      )}

      {pdfBytes && (
        <ToolCard title="Save">
          <Field label="Save plot into show">
            <Select<string>
              value=""
              onChange={(v) => v && void saveToShow(v as ShowId)}
              options={[
                { value: '', label: shows.length ? 'Choose a show…' : 'No saved shows yet' },
                ...shows.map((s) => ({ value: s.id as string, label: s.name })),
              ]}
            />
          </Field>
          {status && <p className="status-line">{status}</p>}
        </ToolCard>
      )}
    </ToolPage>
  );
}
