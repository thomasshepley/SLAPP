import { Link } from 'react-router-dom';
import { useActiveShow } from '@/hooks/useActiveShow';
import { FEATURES } from './manifest';

export function Home() {
  const { show } = useActiveShow();

  return (
    <section className="page">
      <h1>Shepley Lighting Companion</h1>
      <p className="muted">
        Offline-first on-set companion for film &amp; TV lighting.
        {show ? ` Working on "${show.name}".` : ' Open or create a show to get started.'}
      </p>
      <div className="grid">
        {FEATURES.map((f) => (
          <Link key={f.id} to={`/f/${f.id}`} className="card">
            <strong>{f.title}</strong>
            <span className="muted">{f.summary}</span>
          </Link>
        ))}
      </div>
    </section>
  );
}
