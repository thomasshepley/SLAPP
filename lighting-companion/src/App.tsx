import { useEffect } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom';
import { useActiveShow } from '@/hooks/useActiveShow';
import { Icon } from '@/components/icons';
import { FEATURES } from '@/features/manifest';

const VERSION = typeof __APP_VERSION__ !== 'undefined' ? __APP_VERSION__ : 'dev';

const NAV_GROUPS = [
  { key: 'production', label: 'Production' },
  { key: 'tools', label: 'On-set tools' },
] as const;

export function App() {
  const { show } = useActiveShow();
  const { pathname } = useLocation();
  const onTool = pathname !== '/';

  // New screen → start at the top (the sidebar keeps you oriented).
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  return (
    <div className="shell">
      <aside className="sidebar" aria-label="Main navigation">
        <Link to="/" className="brand">
          <span className="brand-mark" aria-hidden="true" />
          <span className="brand-text">Lighting&nbsp;Co.</span>
        </Link>

        <Link to="/f/shows" className={`side-show${show ? ' side-show-on' : ''}`}>
          <span className="side-show-label">{show ? 'Active show' : 'No active show'}</span>
          <span className="side-show-name">{show ? show.name : 'Choose or create one →'}</span>
        </Link>

        <nav className="side-nav">
          <NavLink to="/" end className="side-link">
            <Icon name="home" /> Home
          </NavLink>
          {NAV_GROUPS.map((g) => (
            <div key={g.key} className="side-group">
              <span className="side-group-label">{g.label}</span>
              {FEATURES.filter((f) => f.group === g.key).map((f) => (
                <NavLink key={f.id} to={`/f/${f.id}`} className="side-link">
                  <Icon name={f.id} /> {f.nav}
                </NavLink>
              ))}
            </div>
          ))}
        </nav>

        <div className="side-foot">
          <NavLink to="/f/settings" className="side-link">
            <Icon name="settings" /> Settings
          </NavLink>
          <span className="side-version">v{VERSION} · offline-ready</span>
        </div>
      </aside>

      <div className="app">
        <header className="topbar">
          {onTool ? (
            <Link to="/" className="topbar-back" aria-label="Home">
              <Icon name="back" size={18} /> Home
            </Link>
          ) : (
            <Link to="/" className="brand">
              <span className="brand-mark" aria-hidden="true" />
              <span className="brand-text">Lighting&nbsp;Co.</span>
              <span className="brand-version">v{VERSION}</span>
            </Link>
          )}
          <div className="topbar-show">
            <Link to="/f/shows" className={show ? 'topbar-show-name' : 'topbar-show-set'} title={show?.name}>
              {show ? show.name : 'Set active show'}
            </Link>
            <Link to="/f/settings" className="topbar-settings" aria-label="Settings" title="Settings">
              <Icon name="settings" />
            </Link>
          </div>
        </header>
        <main>
          <Outlet />
        </main>
        <footer className="appfoot">
          <span>Shepley Lighting Companion</span>
          <span className="appfoot-sep">·</span>
          <span>v{VERSION}</span>
          <span className="appfoot-sep">·</span>
          <span>offline-ready</span>
        </footer>
      </div>
    </div>
  );
}
