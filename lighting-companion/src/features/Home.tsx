import { Link } from 'react-router-dom';
import { useActiveShow } from '@/hooks/useActiveShow';
import { useFixtures } from '@/hooks/useLibrary';
import { Icon } from '@/components/icons';
import { FEATURES, type FeatureDef } from './manifest';

const GROUPS: Array<{ key: FeatureDef['group']; label: string }> = [
  { key: 'production', label: 'Production' },
  { key: 'tools', label: 'On-set tools' },
  { key: 'system', label: 'System' },
];

export function Home() {
  const { show } = useActiveShow();
  const fixtures = useFixtures();
  const patched = show?.patch.length ?? 0;
  const universes = show ? new Set(show.patch.map((p) => p.universe)).size : 0;
  const consoleName = show?.console.type === 'titan' ? 'Avolites Titan' : 'grandMA3';

  return (
    <section className="page">
      <p className="eyebrow">Shepley Lighting Companion</p>
      <h1>{greeting()}</h1>
      <p className="muted lede">Your on-set lighting toolkit — works fully offline.</p>

      <div className="hero">
        {show ? (
          <div className="hero-show">
            <span className="hero-label">Active show</span>
            <strong className="hero-title">{show.name}</strong>
            <div className="hero-stats">
              <Stat value={patched} label={patched === 1 ? 'fixture patched' : 'fixtures patched'} />
              <Stat value={universes} label={universes === 1 ? 'universe' : 'universes'} />
              <Stat value={consoleName} label="console" />
            </div>
            <div className="hero-actions">
              <Link to="/f/showfile" className="btn btn-sm">
                <Icon name="showfile" size={16} /> Build patch
              </Link>
              <Link to="/f/console" className="btn btn-sm btn-secondary">
                <Icon name="console" size={16} /> Export to console
              </Link>
              <Link to="/f/shows" className="btn btn-sm btn-ghost">Switch show</Link>
            </div>
          </div>
        ) : (
          <div className="hero-show">
            <span className="hero-label">Get started</span>
            <strong className="hero-title">Create a show for this job</strong>
            <p className="muted">
              Shows hold your patch, plot and power budget. Everything stays on this device.
            </p>
            <div className="hero-actions">
              <Link to="/f/shows" className="btn btn-sm">
                <Icon name="shows" size={16} /> New show
              </Link>
              <Link to="/f/fixtures" className="btn btn-sm btn-secondary">Browse fixtures</Link>
            </div>
          </div>
        )}
        <Link to="/f/fixtures" className="hero-library">
          <span className="hero-label">Fixture library</span>
          <strong className="hero-big">{fixtures.length}</strong>
          <span className="muted">
            fixtures · {new Set(fixtures.map((f) => f.manufacturer)).size} brands · cached offline
          </span>
        </Link>
      </div>

      {GROUPS.map(({ key, label }) => {
        const items = FEATURES.filter((f) => f.group === key);
        return (
          <div key={key}>
            <h2 className="home-group-label">{label}</h2>
            <div className="grid">
              {items.map((f) => (
                <Link key={f.id} to={`/f/${f.id}`} className="card">
                  <span className="card-icon"><Icon name={f.id} size={22} /></span>
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

function Stat({ value, label }: { value: number | string; label: string }) {
  return (
    <span className="stat">
      <strong>{value}</strong>
      <span>{label}</span>
    </span>
  );
}

function greeting(): string {
  const h = new Date().getHours();
  if (h < 5) return 'Late call';
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}
