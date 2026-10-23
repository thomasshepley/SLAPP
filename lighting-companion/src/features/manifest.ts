export interface FeatureDef {
  id: string;
  section: number;
  title: string;
  /** Short label for the sidebar. */
  nav: string;
  summary: string;
  group: 'production' | 'tools' | 'system';
}

export const FEATURES: FeatureDef[] = [
  { id: 'shows', section: 2, title: 'Shows', nav: 'Shows', summary: 'Create, open, duplicate and share your jobs.', group: 'production' },
  { id: 'fixtures', section: 3, title: 'Fixture Library', nav: 'Fixtures', summary: '220+ fixtures with DMX charts, plot symbols and specs.', group: 'production' },
  { id: 'showfile', section: 4, title: 'New Showfile', nav: 'Showfile', summary: 'Build a patch, auto-pack addresses, print a cheat sheet.', group: 'production' },
  { id: 'plot', section: 6, title: 'Polycam Plot', nav: 'Plot', summary: 'Import a Polycam PDF and tap to tag fixtures on the plan.', group: 'production' },
  { id: 'console', section: 1, title: 'Console Export', nav: 'Console', summary: 'Send a show’s patch to grandMA3 or Titan as CSV, macro and symbols.', group: 'production' },
  { id: 'stops', section: 5, title: 'Stops', nav: 'Stops', summary: '± stops from DMX levels via real dimming curves.', group: 'tools' },
  { id: 'beam', section: 9, title: 'Beam & Photometry', nav: 'Beam', summary: 'Inverse square law, beam coverage, throw distance.', group: 'tools' },
  { id: 'power', section: 10, title: 'Power', nav: 'Power', summary: 'Budget the rig and size the cable.', group: 'tools' },
  { id: 'colour', section: 7, title: 'Colour', nav: 'Colour', summary: 'Gel search, mired shift, CTO/CTB, tint.', group: 'tools' },
  { id: 'camera', section: 8, title: 'Camera & Exposure', nav: 'Camera', summary: 'Exposure, flicker-free shutter, ND stack.', group: 'tools' },
  { id: 'reference', section: 11, title: 'Sun & Sync', nav: 'Sun & Sync', summary: 'Sunrise, golden & blue hour, sun position, gobo BPM.', group: 'tools' },
  { id: 'settings', section: 12, title: 'Settings', nav: 'Settings', summary: 'Units, mains frequency, supply voltage.', group: 'system' },
];

export const featureById = (id: string): FeatureDef | undefined => FEATURES.find((f) => f.id === id);
