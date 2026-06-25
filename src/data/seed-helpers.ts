import type { Fixture, FixtureMode } from '@/models/fixture';

export type FixtureSeed = Omit<
  Fixture,
  'id' | 'createdAt' | 'updatedAt' | 'schemaVersion' | 'userModified' | 'source'
> & { seedKey: string };

export const intensityFirst = (extra: FixtureMode['channels'] = []): FixtureMode['channels'] => [
  { offset: 0, resolution: 8, attribute: 'intensity', label: 'Dimmer' },
  ...extra,
];

export const dimmerOnly = (): FixtureMode['channels'] => intensityFirst();

export const cctChannels = (): FixtureMode['channels'] =>
  intensityFirst([
    { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
    { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
  ]);

export const rgbwChannels = (extra: FixtureMode['channels'] = []): FixtureMode['channels'] =>
  intensityFirst([
    { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
    { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
    { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
    { offset: 4, resolution: 8, attribute: 'white', label: 'White' },
    ...extra,
  ]);

export const rgbwExtChannels = (): FixtureMode['channels'] =>
  rgbwChannels([
    { offset: 5, resolution: 8, attribute: 'cct', label: 'CCT' },
    { offset: 6, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
    { offset: 7, resolution: 8, attribute: 'control', label: 'Fan Mode' },
    { offset: 8, resolution: 8, attribute: 'control', label: 'Control' },
  ]);

export const hsiChannels = (): FixtureMode['channels'] =>
  intensityFirst([
    { offset: 1, resolution: 8, attribute: 'other', label: 'Hue' },
    { offset: 2, resolution: 8, attribute: 'other', label: 'Saturation' },
  ]);

export const movingHeadChannels = (): FixtureMode['channels'] =>
  intensityFirst([
    { offset: 1, resolution: 16, attribute: 'pan', label: 'Pan' },
    { offset: 3, resolution: 16, attribute: 'tilt', label: 'Tilt' },
    { offset: 5, resolution: 8, attribute: 'zoom', label: 'Zoom' },
    { offset: 6, resolution: 8, attribute: 'focus', label: 'Focus' },
    { offset: 7, resolution: 8, attribute: 'red', label: 'Red' },
    { offset: 8, resolution: 8, attribute: 'green', label: 'Green' },
    { offset: 9, resolution: 8, attribute: 'blue', label: 'Blue' },
    { offset: 10, resolution: 8, attribute: 'white', label: 'White' },
    { offset: 11, resolution: 8, attribute: 'cct', label: 'CCT' },
    { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
  ]);

export const pixelTubeChannels = (): FixtureMode['channels'] =>
  intensityFirst([
    { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
    { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
    { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
    { offset: 4, resolution: 8, attribute: 'white', label: 'White' },
    { offset: 5, resolution: 8, attribute: 'other', label: 'Effect' },
    { offset: 6, resolution: 8, attribute: 'other', label: 'Effect Speed' },
    { offset: 7, resolution: 8, attribute: 'control', label: 'Control' },
  ]);
