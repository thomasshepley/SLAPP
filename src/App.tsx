import { Link, Outlet } from 'react-router-dom';

export function App() {
  return (
    <div className="app">
      <header className="topbar">
        <Link to="/" className="brand">
          Lighting Co.
        </Link>
        <span className="muted">offline-ready</span>
      </header>
      <main>
        <Outlet />
      </main>
    </div>
  );
}
