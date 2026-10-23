import { DEFAULT_PHOTOMETRY_KEY } from '@/models/fixture';
import type { FixtureSeed } from './seed-helpers';
import { dimmerOnly, cctChannels, rgbwChannels, pixelTubeChannels, hsiChannels } from './seed-helpers';

/**
 * Godox fixture seeds.
 *
 * Skipped (already in main seed list):
 *   Knowled M600D, Knowled M300D, Knowled P600Bi, TL120,
 *   Knowled MG1200Bi, Knowled M200D, Knowled P300R, VL150, SL150 III
 */

export const GODOX_SEEDS: FixtureSeed[] = [
  // ---------------------------------------------------------------------------
  // Knowled M-Series COBs
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-knowled-m600bi',
    manufacturer: 'Godox',
    model: 'Knowled M600Bi',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 58000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 5.5,
  },
  {
    seedKey: 'godox-knowled-m400d',
    manufacturer: 'Godox',
    model: 'Knowled M400D',
    category: 'LED COB',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 400,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 52000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 3.8,
  },
  {
    seedKey: 'godox-knowled-m400bi',
    manufacturer: 'Godox',
    model: 'Knowled M400Bi',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 400,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 42000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 3.8,
  },
  {
    seedKey: 'godox-knowled-m200bi',
    manufacturer: 'Godox',
    model: 'Knowled M200Bi',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 20000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 2.5,
  },

  // ---------------------------------------------------------------------------
  // Knowled MG-Series (big cinema)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-knowled-mg2400bi',
    manufacturer: 'Godox',
    model: 'Knowled MG2400Bi',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 2400,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 180000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 97, tlci: 98, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 19,
  },

  // ---------------------------------------------------------------------------
  // Knowled F-Series (Flex panels)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-knowled-f600bi',
    manufacturer: 'Godox',
    model: 'Knowled F600Bi',
    category: 'LED Flex Panel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 8500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 97, tlci: 98, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 3.5,
  },
  {
    seedKey: 'godox-knowled-f200bi',
    manufacturer: 'Godox',
    model: 'Knowled F200Bi',
    category: 'LED Flex Panel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 1.3,
  },

  // ---------------------------------------------------------------------------
  // Knowled P-Series (panels)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-knowled-p600r',
    manufacturer: 'Godox',
    model: 'Knowled P600R',
    category: 'LED Panel',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 7500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 97, tlci: 98, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 9,
  },

  // ---------------------------------------------------------------------------
  // SL-Series (budget COBs)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-sl-200-iii',
    manufacturer: 'Godox',
    model: 'SL-200 III',
    category: 'LED COB',
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
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 2.2,
  },
  {
    seedKey: 'godox-sl-100bi',
    manufacturer: 'Godox',
    model: 'SL-100Bi',
    category: 'LED COB',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 100,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 10000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 1.5,
  },
  {
    seedKey: 'godox-sl-60w',
    manufacturer: 'Godox',
    model: 'SL-60W',
    category: 'LED COB',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 60,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 6000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 1.0,
  },

  // ---------------------------------------------------------------------------
  // UL-Series (ultra-silent)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-ul150',
    manufacturer: 'Godox',
    model: 'UL150',
    category: 'LED COB',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 18000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 2.0,
  },
  {
    seedKey: 'godox-ul60',
    manufacturer: 'Godox',
    model: 'UL60',
    category: 'LED COB',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 60,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5800, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 1.0,
  },

  // ---------------------------------------------------------------------------
  // Tube Lights
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-tl30',
    manufacturer: 'Godox',
    model: 'TL30',
    category: 'LED Tube',
    modes: [
      {
        name: 'Pixel Tube',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 18,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 650, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2800, maxK: 8500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.3,
  },
  {
    seedKey: 'godox-tl60',
    manufacturer: 'Godox',
    model: 'TL60',
    category: 'LED Tube',
    modes: [
      {
        name: 'Pixel Tube',
        channelCount: 8,
        channels: pixelTubeChannels(),
        powerW: 25,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1100, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2800, maxK: 8500 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.5,
  },

  // ---------------------------------------------------------------------------
  // FV Series (flash+continuous)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-fv150',
    manufacturer: 'Godox',
    model: 'FV150',
    category: 'LED COB',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 15000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 2.0,
  },
  {
    seedKey: 'godox-fv200',
    manufacturer: 'Godox',
    model: 'FV200',
    category: 'LED COB',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 22000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 2.5,
  },

  // ---------------------------------------------------------------------------
  // Special
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-lc500r',
    manufacturer: 'Godox',
    model: 'LC500R',
    category: 'LED Light Stick',
    modes: [
      {
        name: 'HSI',
        channelCount: 3,
        channels: hsiChannels(),
        powerW: 36,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 550, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2500, maxK: 8500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 0.6,
  },
  {
    seedKey: 'godox-sz150r',
    manufacturer: 'Godox',
    model: 'SZ150R',
    category: 'LED COB',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 5,
        channels: rgbwChannels(),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 18000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 2800, maxK: 6500 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 10, maxDeg: 60 } },
    weightKg: 2.8,
  },

  // ---------------------------------------------------------------------------
  // Litemons Series (budget)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-litemons-la150bi',
    manufacturer: 'Godox',
    model: 'Litemons LA150Bi',
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
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 14000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 120 },
    weightKg: 1.6,
  },
  {
    seedKey: 'godox-litemons-la200d',
    manufacturer: 'Godox',
    model: 'Litemons LA200D',
    category: 'LED COB',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 22000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 1.8,
  },
  {
    seedKey: 'godox-litemons-la150d',
    manufacturer: 'Godox',
    model: 'Litemons LA150D',
    category: 'LED COB',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 16000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 1.5,
  },
];
