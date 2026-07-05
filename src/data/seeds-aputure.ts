import { DEFAULT_PHOTOMETRY_KEY } from '@/models/fixture';
import type { FixtureSeed } from './seed-helpers';
import { dimmerOnly, rgbwChannels, cctChannels, hsiChannels, pixelTubeChannels } from './seed-helpers';

export const APUTURE_SEEDS: FixtureSeed[] = [
  // ---------------------------------------------------------------------------
  // LS / COB Series
  // ---------------------------------------------------------------------------
  {
    seedKey: 'aputure-ls-300d-ii',
    manufacturer: 'Aputure',
    model: 'LS 300D II',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Intensity',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 58000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5500 },
    beam: { angleDeg: 120 },
    weightKg: 3.1,
  },
  {
    seedKey: 'aputure-ls-600d',
    manufacturer: 'Aputure',
    model: 'LS 600D',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Intensity',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 87000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 6.5,
  },
  {
    seedKey: 'aputure-ls-1200d',
    manufacturer: 'Aputure',
    model: 'LS 1200D',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Intensity',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 1200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 83000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 7.8,
  },
  {
    seedKey: 'aputure-ls-600c',
    manufacturer: 'Aputure',
    model: 'LS 600C',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 60000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2300, maxK: 10000 } },
    beam: { angleDeg: 120 },
    weightKg: 6.5,
  },

  // ---------------------------------------------------------------------------
  // Amaran COB Series
  // ---------------------------------------------------------------------------
  {
    seedKey: 'aputure-amaran-60d-s',
    manufacturer: 'Aputure',
    model: 'Amaran 60D S',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Intensity',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 65,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 7800, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 0.68,
  },
  {
    seedKey: 'aputure-amaran-100d-s',
    manufacturer: 'Aputure',
    model: 'Amaran 100D S',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Intensity',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 100,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 14000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 0.85,
  },
  {
    seedKey: 'aputure-amaran-100x-s',
    manufacturer: 'Aputure',
    model: 'Amaran 100X S',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 100,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 11000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 0.85,
  },
  {
    seedKey: 'aputure-amaran-200d-s',
    manufacturer: 'Aputure',
    model: 'Amaran 200D S',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Intensity',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 28000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 1.6,
  },
  {
    seedKey: 'aputure-amaran-200x-s',
    manufacturer: 'Aputure',
    model: 'Amaran 200X S',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 22000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 1.6,
  },

  // ---------------------------------------------------------------------------
  // Amaran Panel / Flex
  // ---------------------------------------------------------------------------
  {
    seedKey: 'aputure-amaran-f21c',
    manufacturer: 'Aputure',
    model: 'Amaran F21C',
    category: 'LED Flexible Mat',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 100,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2100, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 1.1,
  },
  {
    seedKey: 'aputure-amaran-f21x',
    manufacturer: 'Aputure',
    model: 'Amaran F21X',
    category: 'LED Flexible Mat',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 4200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 1.1,
  },
  {
    seedKey: 'aputure-amaran-p60c',
    manufacturer: 'Aputure',
    model: 'Amaran P60C',
    category: 'LED Softlight',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 60,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 1.2,
  },
  {
    seedKey: 'aputure-amaran-p60x',
    manufacturer: 'Aputure',
    model: 'Amaran P60X',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 60,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3800, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 3200, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 1.0,
  },

  // ---------------------------------------------------------------------------
  // Amaran Tube Series
  // ---------------------------------------------------------------------------
  {
    seedKey: 'aputure-amaran-t2c',
    manufacturer: 'Aputure',
    model: 'Amaran T2C',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 10,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 800, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.4,
  },
  {
    seedKey: 'aputure-amaran-t4c',
    manufacturer: 'Aputure',
    model: 'Amaran T4C',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 20,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.7,
  },
  {
    seedKey: 'aputure-amaran-pt1c',
    manufacturer: 'Aputure',
    model: 'Amaran PT1C',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 6,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 350, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.2,
  },
  {
    seedKey: 'aputure-amaran-pt2c',
    manufacturer: 'Aputure',
    model: 'Amaran PT2C',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 15,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 700, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.4,
  },
  {
    seedKey: 'aputure-amaran-pt4c',
    manufacturer: 'Aputure',
    model: 'Amaran PT4C',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 30,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1100, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.8,
  },

  // ---------------------------------------------------------------------------
  // Accent / Bulb
  // ---------------------------------------------------------------------------
  {
    seedKey: 'aputure-accent-b7c',
    manufacturer: 'Aputure',
    model: 'Accent B7C',
    category: 'LED Bulb',
    modes: [
      {
        name: 'HSI',
        channelCount: 3,
        channels: hsiChannels(),
        powerW: 7,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2000, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 160 },
    weightKg: 0.12,
  },

  // ---------------------------------------------------------------------------
  // Infinibar
  // ---------------------------------------------------------------------------
  {
    seedKey: 'aputure-infinibar-pb3',
    manufacturer: 'Aputure',
    model: 'Infinibar PB3',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 45,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1800, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 1.5,
  },
  {
    seedKey: 'aputure-infinibar-pb12',
    manufacturer: 'Aputure',
    model: 'Infinibar PB12',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 180,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 6.0,
  },

  // ---------------------------------------------------------------------------
  // MT Pro
  // ---------------------------------------------------------------------------
  {
    seedKey: 'aputure-mt-pro',
    manufacturer: 'Aputure',
    model: 'MT Pro',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 16,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 600, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2000, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.35,
  },
];
