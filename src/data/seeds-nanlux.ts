import { DEFAULT_PHOTOMETRY_KEY } from '@/models/fixture';
import type { FixtureSeed } from './seed-helpers';
import { intensityFirst, dimmerOnly, cctChannels, rgbwChannels } from './seed-helpers';

export const NANLUX_SEEDS: FixtureSeed[] = [
  // ---------------------------------------------------------------------------
  // Evoke Series
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlux-evoke-300',
    manufacturer: 'Nanlux',
    model: 'Evoke 300',
    category: 'LED Spot',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 42000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 15 },
    weightKg: 3.5,
  },
  {
    seedKey: 'nanlux-evoke-300b',
    manufacturer: 'Nanlux',
    model: 'Evoke 300B',
    category: 'LED Spot',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 32000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 15 },
    weightKg: 3.5,
  },
  {
    seedKey: 'nanlux-evoke-600',
    manufacturer: 'Nanlux',
    model: 'Evoke 600',
    category: 'LED Spot',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 72000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 15 },
    weightKg: 5.5,
  },
  {
    seedKey: 'nanlux-evoke-600b',
    manufacturer: 'Nanlux',
    model: 'Evoke 600B',
    category: 'LED Spot',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 55000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 15 },
    weightKg: 5.5,
  },
  {
    seedKey: 'nanlux-evoke-900',
    manufacturer: 'Nanlux',
    model: 'Evoke 900',
    category: 'LED Spot',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 900,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 110000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 15 },
    weightKg: 7.5,
  },
  {
    seedKey: 'nanlux-evoke-1200b',
    manufacturer: 'Nanlux',
    model: 'Evoke 1200B',
    category: 'LED Spot',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 1200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 95000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 15 },
    weightKg: 10,
  },

  // ---------------------------------------------------------------------------
  // Dyno Series (panels)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlux-dyno-300c',
    manufacturer: 'Nanlux',
    model: 'Dyno 300C',
    category: 'LED Panel',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 4500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 7,
  },
  {
    seedKey: 'nanlux-dyno-1200b',
    manufacturer: 'Nanlux',
    model: 'Dyno 1200B',
    category: 'LED Panel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 1200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 12000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 110 },
    weightKg: 22,
  },

  // ---------------------------------------------------------------------------
  // TK Series (compact Fresnel)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlux-tk-200',
    manufacturer: 'Nanlux',
    model: 'TK-200',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 25000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 45 } },
    weightKg: 2.8,
  },
  {
    seedKey: 'nanlux-tk-200b',
    manufacturer: 'Nanlux',
    model: 'TK-200B',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 19000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 45 } },
    weightKg: 2.8,
  },
  {
    seedKey: 'nanlux-tk-300',
    manufacturer: 'Nanlux',
    model: 'TK-300',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 38000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 45 } },
    weightKg: 3.2,
  },
  {
    seedKey: 'nanlux-tk-600',
    manufacturer: 'Nanlux',
    model: 'TK-600',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 68000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 45 } },
    weightKg: 5.0,
  },
];
