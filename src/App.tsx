import { Link, Outlet } from 'react-router-dom';
import { useActiveShow } from '@/hooks/useActiveShow';

const VERSION = typeof __APP_VERSION__ !== 'undefined' ? __APP_VERSION__ : 'dev';

export function App() {
  const { show } = useActiveShow();

  return (
    <div className="app">
      <header className="topbar">
        <Link to="/" className="brand">
          <span className="brand-mark" aria-hidden="true" />
          <span className="brand-text">Lighting&nbsp;Co.</span>
          <span className="brand-version" title={`Version ${VERSION}`}>
            v{VERSION}
          </span>
        </Link>
        <div className="topbar-show">
          {show ? (
            <Link to="/f/shows" className="topbar-show-name" title={show.name}>
              {show.name}
            </Link>
          ) : (
            <Link to="/f/shows" className="topbar-show-set">
              Set active show
            </Link>
          )}
          <Link to="/f/settings" className="topbar-settings" aria-label="Settings" title="Settings">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="10" cy="10" r="3"/>
              <path d="M10 1.5v2M10 16.5v2M3.4 3.4l1.4 1.4M15.2 15.2l1.4 1.4M1.5 10h2M16.5 10h2M3.4 16.6l1.4-1.4M15.2 4.8l1.4-1.4"/>
            </svg>
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
  );
}
