/**
 * The app's feature map, one entry per section of the v0.1 brief. Drives the
 * nav and the route table. Each feature gets its own module under
 * src/features/<id> as it's built; until then they share the Placeholder page.
 */
export interface FeatureDef {
  id: string;
  /** Brief section number, for traceability. */
  section: number;
  title: string;
  /** One-line scope reminder shown on the placeholder. */
  summary: string;
}

export const FEATURES: FeatureDef[] = [
  { id: 'shows', section: 2, title: 'Shows', summary: 'Save, open, duplicate, export and cross-import jobs.' },
  { id: 'console', section: 1, title: 'Console', summary: 'Connect to MA3 / Titan; pull & push patch and levels.' },
  { id: 'fixtures', section: 3, title: 'Fixtures', summary: 'Local fixture library, GDTF sync, comparator.' },
  { id: 'showfile', section: 4, title: 'New Showfile', summary: 'Build a patch, pack addresses, push, generate cheat sheet.' },
  { id: 'stops', section: 5, title: 'Stops', summary: 'Live ± stops from console levels via dimming curves.' },
  { id: 'plot', section: 6, title: 'Plot', summary: 'Import Polycam PDF, tag fixtures on the plan.' },
  { id: 'colour', section: 7, title: 'Colour', summary: 'Gel search, gel→RGB/HSI, CTO/CTB, mired, Duv.' },
  { id: 'camera', section: 8, title: 'Camera', summary: 'Exposure, flicker-free shutter, ND stack, CRI/TLCI.' },
  { id: 'beam', section: 9, title: 'Beam', summary: 'Inverse square law, beam coverage, throw reference.' },
  { id: 'power', section: 10, title: 'Power', summary: 'Power budget and cable derating reference.' },
  { id: 'reference', section: 11, title: 'Reference', summary: 'Sun position, gobo BPM, DMX table & manual browser.' },
];
