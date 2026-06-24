export interface FeatureDef {
  id: string;
  section: number;
  title: string;
  summary: string;
}

export const FEATURES: FeatureDef[] = [
  { id: 'shows', section: 2, title: 'Shows', summary: 'Open, create, duplicate, export and import your jobs.' },
  { id: 'fixtures', section: 3, title: 'Fixtures', summary: 'Browse the fixture library, DMX charts, and compare specs.' },
  { id: 'showfile', section: 4, title: 'New Showfile', summary: 'Build a patch, auto-pack addresses, print cheat sheets.' },
  { id: 'stops', section: 5, title: 'Stops', summary: 'Calculate ± stops from DMX levels via dimming curves.' },
  { id: 'beam', section: 9, title: 'Beam & Photometry', summary: 'Inverse square law, beam coverage, throw distance.' },
  { id: 'power', section: 10, title: 'Power', summary: 'Power budget your rig and size the cable.' },
  { id: 'colour', section: 7, title: 'Colour', summary: 'Gel search, mired shift, CTO/CTB, tint analysis.' },
  { id: 'camera', section: 8, title: 'Camera & Exposure', summary: 'Exposure, flicker-free shutter, ND stack.' },
  { id: 'reference', section: 11, title: 'Reference', summary: 'Sun position, gobo BPM, cable ratings.' },
  { id: 'plot', section: 6, title: 'Polycam Plot', summary: 'Import Polycam PDF, tap to tag fixtures on the plan.' },
  { id: 'console', section: 1, title: 'Console', summary: 'Connect to MA3 or Titan (needs hardware).' },
];
