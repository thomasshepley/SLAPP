export interface FeatureDef {
  id: string;
  section: number;
  title: string;
  summary: string;
  group: 'production' | 'tools' | 'reference' | 'system';
}

export const FEATURES: FeatureDef[] = [
  { id: 'shows', section: 2, title: 'Shows', summary: 'Open, create, duplicate, export and import your jobs.', group: 'production' },
  { id: 'fixtures', section: 3, title: 'Fixtures', summary: 'Browse the fixture library, DMX charts, and compare specs.', group: 'production' },
  { id: 'showfile', section: 4, title: 'New Showfile', summary: 'Build a patch, auto-pack addresses, print cheat sheets.', group: 'production' },
  { id: 'stops', section: 5, title: 'Stops', summary: 'Calculate ± stops from DMX levels via dimming curves.', group: 'tools' },
  { id: 'beam', section: 9, title: 'Beam & Photometry', summary: 'Inverse square law, beam coverage, throw distance.', group: 'tools' },
  { id: 'power', section: 10, title: 'Power', summary: 'Power budget your rig and size the cable.', group: 'tools' },
  { id: 'colour', section: 7, title: 'Colour', summary: 'Gel search, mired shift, CTO/CTB, tint analysis.', group: 'tools' },
  { id: 'camera', section: 8, title: 'Camera & Exposure', summary: 'Exposure, flicker-free shutter, ND stack.', group: 'tools' },
  { id: 'reference', section: 11, title: 'Reference', summary: 'Sun position, gobo BPM, cable ratings.', group: 'reference' },
  { id: 'plot', section: 6, title: 'Polycam Plot', summary: 'Import Polycam PDF, tap to tag fixtures on the plan.', group: 'production' },
  { id: 'console', section: 1, title: 'Console', summary: 'Connect to MA3 or Titan (needs hardware).', group: 'system' },
  { id: 'settings', section: 12, title: 'Settings', summary: 'Units, mains frequency, supply voltage, preferences.', group: 'system' },
];
