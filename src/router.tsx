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
      // Console and plot still use the placeholder shell.
      { path: 'f/:featureId', element: <Placeholder /> },
    ],
  },
]);
