import { Link } from 'react-router-dom';
import { useActiveShow } from '@/hooks/useActiveShow';
import { FEATURES, type FeatureDef } from './manifest';

const GROUPS: Array<{ key: FeatureDef['group']; label: string }> = [
  { key: 'production', label: 'Production' },
  { key: 'tools', label: 'On-Set Tools' },
  { key: 'reference', label: 'Reference' },
  { key: 'system', label: 'System' },
];

export function Home() {
  const { show } = useActiveShow();

  return (
    <section className="page">
      <h1>Shepley Lighting Companion</h1>
      <p className="muted">
        Offline-first on-set companion for film &amp; TV lighting.
        {show ? ` Working on "${show.name}".` : ' Open or create a show to get started.'}
      </p>

      {show && (
        <div className="home-quick-actions">
          <Link to="/f/showfile" className="chip">New Showfile</Link>
          <Link to="/f/fixtures" className="chip">Fixtures</Link>
          <Link to="/f/stops" className="chip">Stops</Link>
          <Link to="/f/beam" className="chip">Beam</Link>
          <Link to="/f/power" className="chip">Power</Link>
        </div>
      )}

      {GROUPS.map(({ key, label }) => {
        const items = FEATURES.filter((f) => f.group === key);
        if (items.length === 0) return null;
        return (
          <div key={key}>
            <h2 className="home-group-label">{label}</h2>
            <div className="grid">
              {items.map((f) => (
                <Link key={f.id} to={`/f/${f.id}`} className="card">
                  <strong>{f.title}</strong>
                  <span className="muted">{f.summary}</span>
                </Link>
              ))}
            </div>
          </div>
        );
      })}
    </section>
  );
}
