import { DEFAULT_PHOTOMETRY_KEY } from '@/models/fixture';
import type { FixtureSeed } from './seed-helpers';
import { dimmerOnly, cctChannels, rgbwChannels, pixelTubeChannels } from './seed-helpers';

export const NANLITE_SEEDS: FixtureSeed[] = [
  // ---------------------------------------------------------------------------
  // Forza Series
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlite-forza-60c',
    manufacturer: 'Nanlite',
    model: 'Forza 60C',
    category: 'LED COB',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 60,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 0.9,
  },
  {
    seedKey: 'nanlite-forza-60b-ii',
    manufacturer: 'Nanlite',
    model: 'Forza 60B II',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 60,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 97, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 0.8,
  },
  {
    seedKey: 'nanlite-forza-150b',
    manufacturer: 'Nanlite',
    model: 'Forza 150B',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 13000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 1.4,
  },
  {
    seedKey: 'nanlite-forza-300',
    manufacturer: 'Nanlite',
    model: 'Forza 300',
    category: 'LED COB',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 35000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 98, tlci: 95, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 2.1,
  },
  {
    seedKey: 'nanlite-forza-300b',
    manufacturer: 'Nanlite',
    model: 'Forza 300B',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 27000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 97, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 2.1,
  },
  {
    seedKey: 'nanlite-forza-300c',
    manufacturer: 'Nanlite',
    model: 'Forza 300C',
    category: 'LED COB',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 25000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 2.2,
  },
  {
    seedKey: 'nanlite-forza-500b-ii',
    manufacturer: 'Nanlite',
    model: 'Forza 500B II',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 500,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 48000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 97, tlci: 98, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 3.5,
  },
  {
    seedKey: 'nanlite-forza-720b',
    manufacturer: 'Nanlite',
    model: 'Forza 720B',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 720,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 72000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 97, tlci: 98, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 4.5,
  },

  // ---------------------------------------------------------------------------
  // Compac / Panel Series
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlite-compac-68b',
    manufacturer: 'Nanlite',
    model: 'Compac 68B',
    category: 'LED Panel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 68,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 4200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 1.3,
  },
  {
    seedKey: 'nanlite-compac-100',
    manufacturer: 'Nanlite',
    model: 'Compac 100',
    category: 'LED Panel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 100,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 7000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 1.5,
  },
  {
    seedKey: 'nanlite-compac-200b',
    manufacturer: 'Nanlite',
    model: 'Compac 200B',
    category: 'LED Panel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 11000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 2.8,
  },
  {
    seedKey: 'nanlite-mixpanel-60',
    manufacturer: 'Nanlite',
    model: 'MixPanel 60',
    category: 'LED Panel',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 60,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 1.2,
  },
  {
    seedKey: 'nanlite-mixpanel-150',
    manufacturer: 'Nanlite',
    model: 'MixPanel 150',
    category: 'LED Panel',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 7500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 2.5,
  },

  // ---------------------------------------------------------------------------
  // PavoSlim Series
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlite-pavoslim-60c',
    manufacturer: 'Nanlite',
    model: 'PavoSlim 60C',
    category: 'LED Panel',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 60,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2800, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 2.2,
  },
  {
    seedKey: 'nanlite-pavoslim-120b',
    manufacturer: 'Nanlite',
    model: 'PavoSlim 120B',
    category: 'LED Panel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 120,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 3.5,
  },

  // ---------------------------------------------------------------------------
  // Tube Series
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlite-mixwand-18',
    manufacturer: 'Nanlite',
    model: 'MixWand 18',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW Pixel',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 18,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.4,
  },
  {
    seedKey: 'nanlite-mixwand-36',
    manufacturer: 'Nanlite',
    model: 'MixWand 36',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW Pixel',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 36,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1800, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.7,
  },
  {
    seedKey: 'nanlite-pavotube-30c',
    manufacturer: 'Nanlite',
    model: 'PavoTube 30C',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW Pixel',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 30,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.9,
  },
  {
    seedKey: 'nanlite-pavotube-t8-7x',
    manufacturer: 'Nanlite',
    model: 'PavoTube T8-7X',
    category: 'LED Tube',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 7,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 400, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 7500 } },
    beam: { angleDeg: 360 },
    weightKg: 0.15,
  },
];
