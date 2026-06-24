import { Link } from 'react-router-dom';
import { FEATURES } from './manifest';

export function Home() {
  return (
    <section className="page">
      <p className="eyebrow">v0.1 scaffold</p>
      <h1>Shepley Lighting Companion</h1>
      <p className="muted">
        Offline-first on-set companion for MA3 &amp; Titan. Pick an area — the
        foundation (data model, IndexedDB storage, calculation engines) is built;
        screens land on top of it next.
      </p>
      <div className="grid">
        {FEATURES.map((f) => (
          <Link key={f.id} to={`/f/${f.id}`} className="card">
            <span className="eyebrow">Section {f.section}</span>
            <strong>{f.title}</strong>
            <span className="muted">{f.summary}</span>
          </Link>
        ))}
      </div>
    </section>
  );
}
