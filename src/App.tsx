import { Link, Outlet } from 'react-router-dom';
import { useActiveShow } from '@/hooks/useActiveShow';

export function App() {
  const { show } = useActiveShow();

  return (
    <div className="app">
      <header className="topbar">
        <Link to="/" className="brand">
          Lighting Co.
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
        </div>
      </header>
      <main>
        <Outlet />
      </main>
    </div>
  );
}
