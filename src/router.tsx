import { lazy, Suspense, type ReactNode } from 'react';
import { createBrowserRouter } from 'react-router-dom';
import { App } from './App';
import { Home } from './features/Home';
import { Placeholder } from './features/Placeholder';
import { ColourTools } from './features/colour/ColourTools';
import { CameraTools } from './features/camera/CameraTools';
import { BeamTools } from './features/beam/BeamTools';
import { PowerTools } from './features/power/PowerTools';
import { ReferenceTools } from './features/reference/ReferenceTools';
import { StopsTool } from './features/stops/StopsTool';
import { FixtureLibrary } from './features/fixtures/FixtureLibrary';
import { Shows } from './features/shows/Shows';
import { ShowfileMacro } from './features/showfile/ShowfileMacro';
import { Settings } from './features/settings/Settings';

// Plot import pulls in pdf.js (large); load it only when the route is opened
// so the app shell stays small and boots fast offline.
const PlotImport = lazy(() =>
  import('./features/plot/PlotImport').then((m) => ({ default: m.PlotImport })),
);

const lazyRoute = (node: ReactNode): ReactNode => (
  <Suspense fallback={<div className="page muted">Loading…</div>}>{node}</Suspense>
);

const basename = import.meta.env.BASE_URL.replace(/\/$/, '') || '/';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <App />,
    children: [
      { index: true, element: <Home /> },
      { path: 'f/colour', element: <ColourTools /> },
      { path: 'f/camera', element: <CameraTools /> },
      { path: 'f/beam', element: <BeamTools /> },
      { path: 'f/power', element: <PowerTools /> },
      { path: 'f/reference', element: <ReferenceTools /> },
      { path: 'f/stops', element: <StopsTool /> },
      { path: 'f/fixtures', element: <FixtureLibrary /> },
      { path: 'f/shows', element: <Shows /> },
      { path: 'f/showfile', element: <ShowfileMacro /> },
      { path: 'f/plot', element: lazyRoute(<PlotImport />) },
      { path: 'f/settings', element: <Settings /> },
      // Console still uses the placeholder shell (needs hardware to integrate).
      { path: 'f/:featureId', element: <Placeholder /> },
    ],
  },
], { basename });
