import { createBrowserRouter } from 'react-router-dom';
import { App } from './App';
import { Home } from './features/Home';
import { Placeholder } from './features/Placeholder';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <App />,
    children: [
      { index: true, element: <Home /> },
      { path: 'f/:featureId', element: <Placeholder /> },
    ],
  },
]);
