import { now, type FixtureId } from '@/models/common';
import { DEFAULT_PHOTOMETRY_KEY, type Fixture, type FixtureMode } from '@/models/fixture';

/**
 * Seed fixture library — a starter set of fixtures common on film/TV sets.
 * Photometry figures are approximate manufacturer specs (centre-beam lux scaled
 * to 1 m), good enough for the stops, ISL and power tools; users refine or add
 * to the library, and GDTF sync fills in channel detail. Channel maps here are
 * deliberately minimal (the attributes the app reasons about), not exhaustive.
 */

type FixtureSeed = Omit<
  Fixture,
  'id' | 'createdAt' | 'updatedAt' | 'schemaVersion' | 'userModified' | 'source'
> & { seedKey: string };

const intensityFirst = (extra: FixtureMode['channels'] = []): FixtureMode['channels'] => [
  { offset: 0, resolution: 8, attribute: 'intensity', label: 'Dimmer' },
  ...extra,
];

const SEED: FixtureSeed[] = [
  // ---------------------------------------------------------------------------
  // ARRI
  // ---------------------------------------------------------------------------
  {
    seedKey: 'arri-skypanel-s60c',
    manufacturer: 'ARRI',
    model: 'SkyPanel S60-C',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Standard (RGBW)',
        channelCount: 11,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 4, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 5, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 6, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 7, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 8, resolution: 8, attribute: 'control', label: 'Control' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Intensity Fine' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'Crossfade' },
        ]),
        powerW: 450,
      },
      {
        name: 'CCT + Tint',
        channelCount: 6,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 5, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 450,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 14500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 90, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 105 },
    weightKg: 14.5,
  },
  {
    seedKey: 'arri-skypanel-s120c',
    manufacturer: 'ARRI',
    model: 'SkyPanel S120-C',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Standard (RGBW)',
        channelCount: 11,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 4, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 5, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 6, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 7, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 8, resolution: 8, attribute: 'control', label: 'Control' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Intensity Fine' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'Crossfade' },
        ]),
        powerW: 800,
      },
      {
        name: 'CCT + Tint',
        channelCount: 6,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 5, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 800,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 28000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 90, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 105 },
    weightKg: 25.5,
  },
  {
    seedKey: 'arri-skypanel-s30c',
    manufacturer: 'ARRI',
    model: 'SkyPanel S30-C',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Standard (RGBW)',
        channelCount: 11,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 4, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 5, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 6, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 7, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 8, resolution: 8, attribute: 'control', label: 'Control' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Intensity Fine' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'Crossfade' },
        ]),
        powerW: 200,
      },
      {
        name: 'CCT + Tint',
        channelCount: 6,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 5, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 7200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 90, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 105 },
    weightKg: 9.5,
  },
  {
    seedKey: 'arri-orbiter',
    manufacturer: 'ARRI',
    model: 'Orbiter',
    category: 'LED Point Source',
    modes: [
      {
        name: 'RGBACL',
        channelCount: 20,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'amber', label: 'Amber' },
          { offset: 6, resolution: 8, attribute: 'cyan', label: 'Cyan' },
          { offset: 7, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 8, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 9, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 11, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 500,
      },
      {
        name: 'CCT',
        channelCount: 8,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 5, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 500,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 61000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 91, cctRange: { minK: 2000, maxK: 11000 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 66 } },
    weightKg: 9.6,
  },
  {
    seedKey: 'arri-skypanel-x21',
    manufacturer: 'ARRI',
    model: 'SkyPanel X21',
    category: 'LED Softlight',
    modes: [
      {
        name: 'RGBACL',
        channelCount: 22,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'amber', label: 'Amber' },
          { offset: 6, resolution: 8, attribute: 'cyan', label: 'Cyan' },
          { offset: 7, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 8, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 9, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 11, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 800,
      },
      {
        name: 'CCT',
        channelCount: 8,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Fan Mode' },
          { offset: 5, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 800,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 26000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 92, cctRange: { minK: 1800, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 30.0,
  },

  // ---------------------------------------------------------------------------
  // Aputure
  // ---------------------------------------------------------------------------
  {
    seedKey: 'aputure-ls-600d-pro',
    manufacturer: 'Aputure',
    model: 'LS 600d Pro',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Intensity',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 720,
      },
      {
        name: 'Simple',
        channelCount: 1,
        channels: intensityFirst(),
        powerW: 720,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 52000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 96, nativeCct: 5600 },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 8.5,
  },
  {
    seedKey: 'aputure-ls-1200d-pro',
    manufacturer: 'Aputure',
    model: 'LS 1200d Pro',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Intensity',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 1440,
      },
      {
        name: 'Simple',
        channelCount: 1,
        channels: intensityFirst(),
        powerW: 1440,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 83000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 96, nativeCct: 5600 },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 13.6,
  },
  {
    seedKey: 'aputure-ls-600x-pro',
    manufacturer: 'Aputure',
    model: 'LS 600x Pro',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 720,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 720,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 46000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 8.7,
  },
  {
    seedKey: 'aputure-ls-300x-ii',
    manufacturer: 'Aputure',
    model: 'LS 300x II',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 350,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 350,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 28500, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 4.7,
  },
  {
    seedKey: 'aputure-nova-p600c',
    manufacturer: 'Aputure',
    model: 'Nova P600c',
    category: 'LED Softlight',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 12,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'Warm White' },
          { offset: 6, resolution: 8, attribute: 'white', label: 'Cool White' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 11, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 600,
      },
      {
        name: 'CCT',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 13200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 97, cctRange: { minK: 2000, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 14.0,
  },
  {
    seedKey: 'aputure-amaran-200d',
    manufacturer: 'Aputure',
    model: 'Amaran 200d',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Intensity',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 200,
      },
      {
        name: 'Simple',
        channelCount: 1,
        channels: intensityFirst(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 16600, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 95, tlci: 95, nativeCct: 5600 },
    beam: { angleDeg: 65, fieldAngleDeg: 90 },
    weightKg: 2.4,
  },
  {
    seedKey: 'aputure-mc',
    manufacturer: 'Aputure',
    model: 'MC',
    category: 'LED Mini Panel',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 7,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 4, resolution: 8, attribute: 'white', label: 'Warm White' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'Cool White' },
          { offset: 6, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 5,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 5,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1100, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 3200, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 0.13,
  },

  // ---------------------------------------------------------------------------
  // Astera
  // ---------------------------------------------------------------------------
  {
    seedKey: 'astera-titan-tube',
    manufacturer: 'Astera',
    model: 'Titan Tube',
    category: 'LED Tube',
    modes: [
      {
        name: '16ch RGBW',
        channelCount: 16,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'amber', label: 'Amber' },
          { offset: 7, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 8, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 9, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 11, resolution: 8, attribute: 'other', label: 'FX Selection' },
          { offset: 12, resolution: 8, attribute: 'other', label: 'FX Speed' },
          { offset: 13, resolution: 8, attribute: 'other', label: 'FX Intensity' },
          { offset: 14, resolution: 8, attribute: 'other', label: 'FX Spread' },
          { offset: 15, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 72,
      },
      {
        name: 'HSI',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Hue' },
          { offset: 2, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 3, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 72,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 72,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1300, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 180 },
    weightKg: 1.5,
  },
  {
    seedKey: 'astera-helios-tube',
    manufacturer: 'Astera',
    model: 'Helios Tube',
    category: 'LED Tube',
    modes: [
      {
        name: '16ch RGBW',
        channelCount: 16,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'amber', label: 'Amber' },
          { offset: 7, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 8, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 9, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 11, resolution: 8, attribute: 'other', label: 'FX Selection' },
          { offset: 12, resolution: 8, attribute: 'other', label: 'FX Speed' },
          { offset: 13, resolution: 8, attribute: 'other', label: 'FX Intensity' },
          { offset: 14, resolution: 8, attribute: 'other', label: 'FX Spread' },
          { offset: 15, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 105,
      },
      {
        name: 'HSI',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Hue' },
          { offset: 2, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 3, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 105,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 105,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2250, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 180 },
    weightKg: 2.4,
  },
  {
    seedKey: 'astera-hydrapanel',
    manufacturer: 'Astera',
    model: 'HydraPanel',
    category: 'LED Softlight',
    modes: [
      {
        name: '16ch RGBW',
        channelCount: 16,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'amber', label: 'Amber' },
          { offset: 7, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 8, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 9, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 11, resolution: 8, attribute: 'other', label: 'FX Selection' },
          { offset: 12, resolution: 8, attribute: 'other', label: 'FX Speed' },
          { offset: 13, resolution: 8, attribute: 'other', label: 'FX Intensity' },
          { offset: 14, resolution: 8, attribute: 'other', label: 'FX Spread' },
          { offset: 15, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 96,
      },
      {
        name: 'HSI',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Hue' },
          { offset: 2, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 3, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 96,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3700, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 1.9,
  },
  {
    seedKey: 'astera-pixelbrick',
    manufacturer: 'Astera',
    model: 'PixelBrick',
    category: 'LED Mini Panel',
    modes: [
      {
        name: 'Full RGBW',
        channelCount: 12,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'amber', label: 'Amber' },
          { offset: 7, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 8, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 9, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 11, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 72,
      },
      {
        name: 'Simple CCT',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 72,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5800, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 95 },
    weightKg: 0.85,
  },

  // ---------------------------------------------------------------------------
  // Nanlux
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlux-evoke-1200',
    manufacturer: 'Nanlux',
    model: 'Evoke 1200',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: '16-bit',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 1350,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 1350,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 92000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 15, fieldAngleDeg: 50 },
    weightKg: 14.5,
  },
  {
    seedKey: 'nanlux-evoke-900c',
    manufacturer: 'Nanlux',
    model: 'Evoke 900C',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Bicolour 16-bit',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 980,
      },
      {
        name: 'Bicolour 8-bit',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 980,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 64000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 15, fieldAngleDeg: 50 },
    weightKg: 13.8,
  },
  {
    seedKey: 'nanlux-dyno-1200c',
    manufacturer: 'Nanlux',
    model: 'Dyno 1200C',
    category: 'LED Softlight',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 14,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'Warm White' },
          { offset: 6, resolution: 8, attribute: 'white', label: 'Cool White' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'Hue' },
          { offset: 11, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
          { offset: 13, resolution: 8, attribute: 'other', label: 'Strobe' },
        ]),
        powerW: 1350,
      },
      {
        name: 'CCT',
        channelCount: 6,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 5, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 1350,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 31000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 21.0,
  },

  // ---------------------------------------------------------------------------
  // Nanlite
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlite-forza-720',
    manufacturer: 'Nanlite',
    model: 'Forza 720',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: '16-bit',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 800,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 800,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 60200, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 98, nativeCct: 5600 },
    beam: { angleDeg: 12, fieldAngleDeg: 40 },
    weightKg: 8.1,
  },
  {
    seedKey: 'nanlite-forza-500-ii',
    manufacturer: 'Nanlite',
    model: 'Forza 500 II',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: '16-bit',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 500,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 500,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 42300, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 98, nativeCct: 5600 },
    beam: { angleDeg: 12, fieldAngleDeg: 40 },
    weightKg: 5.6,
  },
  {
    seedKey: 'nanlite-forza-300b-ii',
    manufacturer: 'Nanlite',
    model: 'Forza 300B II',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Bicolour 16-bit',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 350,
      },
      {
        name: 'Bicolour 8-bit',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 350,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 22800, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 12, fieldAngleDeg: 40 },
    weightKg: 3.8,
  },
  {
    seedKey: 'nanlite-pavotube-ii-30x',
    manufacturer: 'Nanlite',
    model: 'PavoTube II 30X',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 12,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'Warm White' },
          { offset: 6, resolution: 8, attribute: 'white', label: 'Cool White' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Hue' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 11, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 25,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 25,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 25,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1050, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 97, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 180 },
    weightKg: 0.9,
  },
  {
    seedKey: 'nanlite-pavoslim-120c',
    manufacturer: 'Nanlite',
    model: 'PavoSlim 120C',
    category: 'LED Softlight',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 12,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'Warm White' },
          { offset: 6, resolution: 8, attribute: 'white', label: 'Cool White' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 11, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 150,
      },
      {
        name: 'CCT',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 7200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 97, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 4.2,
  },

  // ---------------------------------------------------------------------------
  // Godox
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-knowled-m600d',
    manufacturer: 'Godox',
    model: 'Knowled M600D',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: '16-bit',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 740,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 740,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 49000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 7.2,
  },
  {
    seedKey: 'godox-knowled-m300d',
    manufacturer: 'Godox',
    model: 'Knowled M300D',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: '16-bit',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 330,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 330,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 27100, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 3.6,
  },
  {
    seedKey: 'godox-knowled-p600bi',
    manufacturer: 'Godox',
    model: 'Knowled P600Bi',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Bicolour Full',
        channelCount: 6,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 5, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 620,
      },
      {
        name: 'Simple',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 620,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 13500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 110 },
    weightKg: 11.4,
  },
  {
    seedKey: 'godox-tl120',
    manufacturer: 'Godox',
    model: 'TL120',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 10,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 4, resolution: 8, attribute: 'white', label: 'Warm White' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'Cool White' },
          { offset: 6, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 7, resolution: 8, attribute: 'other', label: 'Hue' },
          { offset: 8, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 9, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 30,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 30,
      },
      {
        name: 'Simple',
        channelCount: 1,
        channels: intensityFirst(),
        powerW: 30,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 960, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 180 },
    weightKg: 0.78,
  },

  // ---------------------------------------------------------------------------
  // Litepanels (existing)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'litepanels-gemini-2x1',
    manufacturer: 'Litepanels',
    model: 'Gemini 2x1 Hard',
    category: 'LED Softlight',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 12,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'Warm White' },
          { offset: 6, resolution: 8, attribute: 'white', label: 'Cool White' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 11, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 325,
      },
      {
        name: 'CCT',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 325,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 11000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 2700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 6.4,
  },

  // ---------------------------------------------------------------------------
  // ETC (existing)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'etc-s4-led-s3-profile',
    manufacturer: 'ETC',
    model: 'Source Four LED Series 3 (Lustr)',
    category: 'LED Profile',
    modes: [
      {
        name: 'Direct',
        channelCount: 11,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 2, resolution: 8, attribute: 'other', label: 'Red-Orange' },
          { offset: 3, resolution: 8, attribute: 'amber', label: 'Amber' },
          { offset: 4, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 5, resolution: 8, attribute: 'cyan', label: 'Cyan' },
          { offset: 6, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 7, resolution: 8, attribute: 'other', label: 'Indigo' },
          { offset: 8, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 210,
      },
      {
        name: 'Studio',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Tint' },
          { offset: 3, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 210,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 38000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 92, tlci: 88, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 14, maxDeg: 70 } },
    weightKg: 9.1,
  },
];

export function seedFixtures(): Fixture[] {
  const stamp = now();
  return SEED.map(({ seedKey, ...rest }) => ({
    ...rest,
    id: `fx-${seedKey}` as FixtureId,
    schemaVersion: 1,
    userModified: false,
    source: { origin: 'curated' as const },
    createdAt: stamp,
    updatedAt: stamp,
  }));
}
