import { now, type FixtureId } from '@/models/common';
import { DEFAULT_PHOTOMETRY_KEY, type Fixture } from '@/models/fixture';
import type { FixtureSeed } from './seed-helpers';
import { intensityFirst } from './seed-helpers';
import { ARRI_SEEDS } from './seeds-arri';
import { APUTURE_SEEDS } from './seeds-aputure';
import { ASTERA_SEEDS } from './seeds-astera';
import { NANLUX_SEEDS } from './seeds-nanlux';
import { NANLITE_SEEDS } from './seeds-nanlite';
import { GODOX_SEEDS } from './seeds-godox';
import { OTHER_SEEDS } from './seeds-other';

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

  // ===========================================================================
  // APPENDED FIXTURES
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Aputure (appended)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'aputure-ls-600c-pro',
    manufacturer: 'Aputure',
    model: 'LS 600c Pro',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 13,
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
          { offset: 11, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 720,
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
        powerW: 720,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 38500, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2300, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 9.2,
  },
  {
    seedKey: 'aputure-electro-storm-cs15',
    manufacturer: 'Aputure',
    model: 'Electro Storm CS15',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 13,
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
          { offset: 11, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 1500,
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
        powerW: 1500,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 70000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2300, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 14.5,
  },
  {
    seedKey: 'aputure-electro-storm-xt26',
    manufacturer: 'Aputure',
    model: 'Electro Storm XT26',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 13,
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
          { offset: 11, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 2600,
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
        powerW: 2600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 115000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2300, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 22.0,
  },
  {
    seedKey: 'aputure-nova-p300c',
    manufacturer: 'Aputure',
    model: 'Nova P300c',
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
        powerW: 350,
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
        powerW: 350,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 8700, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 97, cctRange: { minK: 2000, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 8.5,
  },
  {
    seedKey: 'aputure-amaran-300c',
    manufacturer: 'Aputure',
    model: 'Amaran 300c',
    category: 'LED Fresnel/COB',
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
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 300,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 21500, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 95, tlci: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 2.8,
  },
  {
    seedKey: 'aputure-amaran-150c',
    manufacturer: 'Aputure',
    model: 'Amaran 150c',
    category: 'LED Fresnel/COB',
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
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 150,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 11200, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 95, tlci: 95, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 1.9,
  },
  {
    seedKey: 'aputure-amaran-f22c',
    manufacturer: 'Aputure',
    model: 'Amaran F22c',
    category: 'LED Flexible Mat',
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
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 200,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 4200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2500, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 130 },
    weightKg: 1.6,
  },
  {
    seedKey: 'aputure-infinibar-pb6',
    manufacturer: 'Aputure',
    model: 'Infinibar PB6',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBWW',
        channelCount: 11,
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
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 60,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 60,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1850, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2000, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 1.2,
  },

  // ---------------------------------------------------------------------------
  // ARRI (appended)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'arri-skypanel-s360c',
    manufacturer: 'ARRI',
    model: 'SkyPanel S360-C',
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
        powerW: 1500,
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
        powerW: 1500,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 42000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 90, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 105 },
    weightKg: 47.0,
  },
  {
    seedKey: 'arri-l5-c',
    manufacturer: 'ARRI',
    model: 'L5-C',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'RGBW',
        channelCount: 9,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 7, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 115,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 115,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5200, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 94, tlci: 90, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 50 } },
    weightKg: 7.6,
  },
  {
    seedKey: 'arri-l7-c',
    manufacturer: 'ARRI',
    model: 'L7-C',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'RGBW',
        channelCount: 9,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 7, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 200,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 10500, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 94, tlci: 90, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 50 } },
    weightKg: 11.4,
  },
  {
    seedKey: 'arri-l10-c',
    manufacturer: 'ARRI',
    model: 'L10-C',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'RGBW',
        channelCount: 9,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 7, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 400,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 400,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 19500, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 94, tlci: 90, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 50 } },
    weightKg: 14.0,
  },

  // ---------------------------------------------------------------------------
  // Astera (appended)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'astera-ax1-pixeltube',
    manufacturer: 'Astera',
    model: 'AX1 PixelTube',
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
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'FX Selection' },
          { offset: 11, resolution: 8, attribute: 'other', label: 'FX Speed' },
          { offset: 12, resolution: 8, attribute: 'other', label: 'FX Intensity' },
          { offset: 13, resolution: 8, attribute: 'other', label: 'FX Spread' },
          { offset: 14, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 36,
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
        powerW: 36,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 36,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 720, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 180 },
    weightKg: 1.1,
  },
  {
    seedKey: 'astera-ax3-lightdrop',
    manufacturer: 'Astera',
    model: 'AX3 LightDrop',
    category: 'LED Mini Panel',
    modes: [
      {
        name: '13ch RGBW',
        channelCount: 13,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'amber', label: 'Amber' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'FX Selection' },
          { offset: 11, resolution: 8, attribute: 'other', label: 'FX Speed' },
          { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 15,
      },
      {
        name: 'HSI',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Hue' },
          { offset: 2, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 15,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 850, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 0.45,
  },
  {
    seedKey: 'astera-nyx-bulb',
    manufacturer: 'Astera',
    model: 'NYX Bulb',
    category: 'LED Bulb',
    modes: [
      {
        name: '13ch RGBW',
        channelCount: 13,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'amber', label: 'Amber' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 10, resolution: 8, attribute: 'other', label: 'FX Selection' },
          { offset: 11, resolution: 8, attribute: 'other', label: 'FX Speed' },
          { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 8,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 8,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 120, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 320 },
    weightKg: 0.12,
  },
  {
    seedKey: 'astera-leofresnel',
    manufacturer: 'Astera',
    model: 'LeoFresnel',
    category: 'LED Fresnel',
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
          { offset: 10, resolution: 8, attribute: 'zoom', label: 'Zoom' },
          { offset: 11, resolution: 8, attribute: 'other', label: 'Strobe' },
          { offset: 12, resolution: 8, attribute: 'other', label: 'FX Selection' },
          { offset: 13, resolution: 8, attribute: 'other', label: 'FX Speed' },
          { offset: 14, resolution: 8, attribute: 'other', label: 'FX Intensity' },
          { offset: 15, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 300,
      },
      {
        name: 'CCT',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'zoom', label: 'Zoom' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 16000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 60 } },
    weightKg: 8.9,
  },

  // ---------------------------------------------------------------------------
  // Nanlux (appended)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlux-evoke-2400b',
    manufacturer: 'Nanlux',
    model: 'Evoke 2400B',
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
        powerW: 2600,
      },
      {
        name: 'Bicolour 8-bit',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 2600,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 124000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 14, fieldAngleDeg: 45 },
    weightKg: 18.5,
  },
  {
    seedKey: 'nanlux-dyno-650c',
    manufacturer: 'Nanlux',
    model: 'Dyno 650C',
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
        powerW: 650,
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
        powerW: 650,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 18500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 13.0,
  },
  {
    seedKey: 'nanlux-tk-450b',
    manufacturer: 'Nanlux',
    model: 'TK-450B',
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
        powerW: 450,
      },
      {
        name: 'Bicolour 8-bit',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 450,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 31000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2700, maxK: 5600 } },
    beam: { angleDeg: 14, fieldAngleDeg: 45 },
    weightKg: 6.2,
  },

  // ---------------------------------------------------------------------------
  // Nanlite (appended)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'nanlite-forza-60-ii',
    manufacturer: 'Nanlite',
    model: 'Forza 60 II',
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
        powerW: 70,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 70,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 11220, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 12, fieldAngleDeg: 40 },
    weightKg: 1.2,
  },
  {
    seedKey: 'nanlite-forza-150',
    manufacturer: 'Nanlite',
    model: 'Forza 150',
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
        powerW: 170,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 170,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 14000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 12, fieldAngleDeg: 40 },
    weightKg: 2.0,
  },
  {
    seedKey: 'nanlite-pavotube-ii-15x',
    manufacturer: 'Nanlite',
    model: 'PavoTube II 15X',
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
        powerW: 15,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 15,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 15,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 620, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 180 },
    weightKg: 0.55,
  },
  {
    seedKey: 'nanlite-pavotube-ii-6c',
    manufacturer: 'Nanlite',
    model: 'PavoTube II 6C',
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
        powerW: 9,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 9,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 310, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2700, maxK: 7500 }, hasColourMixing: true },
    beam: { angleDeg: 180 },
    weightKg: 0.28,
  },
  {
    seedKey: 'nanlite-fc-500b',
    manufacturer: 'Nanlite',
    model: 'FC-500B',
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
        powerW: 500,
      },
      {
        name: 'Bicolour 8-bit',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 500,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 34000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 12, fieldAngleDeg: 45 },
    weightKg: 4.4,
  },
  {
    seedKey: 'nanlite-compac-200',
    manufacturer: 'Nanlite',
    model: 'Compac 200',
    category: 'LED Softlight',
    modes: [
      {
        name: 'CCT',
        channelCount: 4,
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
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 4300, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, nativeCct: 5600 },
    beam: { angleDeg: 120 },
    weightKg: 3.2,
  },

  // ---------------------------------------------------------------------------
  // Godox (appended)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'godox-knowled-mg1200bi',
    manufacturer: 'Godox',
    model: 'Knowled MG1200Bi',
    category: 'LED Fresnel/COB',
    modes: [
      {
        name: 'Bicolour 16-bit',
        channelCount: 6,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 5, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 1300,
      },
      {
        name: 'Simple',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 1300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 89000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 2800, maxK: 6500 } },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 12.2,
  },
  {
    seedKey: 'godox-knowled-m200d',
    manufacturer: 'Godox',
    model: 'Knowled M200D',
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
        powerW: 230,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 230,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 18500, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 97, nativeCct: 5600 },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 3.0,
  },
  {
    seedKey: 'godox-knowled-p300r',
    manufacturer: 'Godox',
    model: 'Knowled P300R',
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
        powerW: 320,
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
        powerW: 320,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 9200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 2500, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 7.0,
  },
  {
    seedKey: 'godox-vl150',
    manufacturer: 'Godox',
    model: 'VL150',
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
        powerW: 150,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 14000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 96, nativeCct: 5600 },
    beam: { angleDeg: 16, fieldAngleDeg: 50 },
    weightKg: 2.5,
  },
  {
    seedKey: 'godox-sl150-iii',
    manufacturer: 'Godox',
    model: 'SL150 III',
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
        powerW: 190,
      },
      {
        name: '8-bit',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 190,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 14500, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 96, nativeCct: 5600 },
    beam: { angleDeg: 16, fieldAngleDeg: 50 },
    weightKg: 2.3,
  },

  // ---------------------------------------------------------------------------
  // Litepanels (appended)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'litepanels-gemini-1x1-hard',
    manufacturer: 'Litepanels',
    model: 'Gemini 1x1 Hard',
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
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 16800, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 2700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 80 },
    weightKg: 4.5,
  },
  {
    seedKey: 'litepanels-gemini-1x1-soft',
    manufacturer: 'Litepanels',
    model: 'Gemini 1x1 Soft',
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
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 9500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 2700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 4.5,
  },
  {
    seedKey: 'litepanels-astra-6x',
    manufacturer: 'Litepanels',
    model: 'Astra 6X',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 130,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 130,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 12000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 65 },
    weightKg: 3.2,
  },

  // ---------------------------------------------------------------------------
  // Creamsource
  // ---------------------------------------------------------------------------
  {
    seedKey: 'creamsource-vortex8',
    manufacturer: 'Creamsource',
    model: 'Vortex8',
    category: 'LED Softlight',
    modes: [
      {
        name: 'RGBW',
        channelCount: 11,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 7, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 8, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 9, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 650,
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
        powerW: 650,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 21000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2200, maxK: 15000 }, hasColourMixing: true },
    beam: { angleDeg: 115 },
    weightKg: 9.8,
  },
  {
    seedKey: 'creamsource-vortex4',
    manufacturer: 'Creamsource',
    model: 'Vortex4',
    category: 'LED Softlight',
    modes: [
      {
        name: 'RGBW',
        channelCount: 11,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 7, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 8, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 9, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
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
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 14500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2200, maxK: 15000 }, hasColourMixing: true },
    beam: { angleDeg: 115 },
    weightKg: 6.0,
  },
  {
    seedKey: 'creamsource-spacex',
    manufacturer: 'Creamsource',
    model: 'SpaceX',
    category: 'LED Softlight',
    modes: [
      {
        name: 'RGBW',
        channelCount: 11,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 7, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 8, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 9, resolution: 8, attribute: 'control', label: 'Fan Control' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 1200,
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
        powerW: 1200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 17500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2200, maxK: 15000 }, hasColourMixing: true },
    beam: { angleDeg: 140 },
    weightKg: 18.0,
  },

  // ---------------------------------------------------------------------------
  // Quasar Science
  // ---------------------------------------------------------------------------
  {
    seedKey: 'quasar-rainbow-2-rr100',
    manufacturer: 'Quasar Science',
    model: 'Rainbow 2 (RR100)',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBX Full',
        channelCount: 11,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 7, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 8, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 9, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 75,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 75,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1450, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2000, maxK: 6000 }, hasColourMixing: true },
    beam: { angleDeg: 240 },
    weightKg: 1.4,
  },
  {
    seedKey: 'quasar-double-rainbow',
    manufacturer: 'Quasar Science',
    model: 'Double Rainbow',
    category: 'LED Tube',
    modes: [
      {
        name: 'RGBX Full',
        channelCount: 11,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'red', label: 'Red' },
          { offset: 3, resolution: 8, attribute: 'green', label: 'Green' },
          { offset: 4, resolution: 8, attribute: 'blue', label: 'Blue' },
          { offset: 5, resolution: 8, attribute: 'white', label: 'White' },
          { offset: 6, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 7, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 8, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 9, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 90,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 90,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1750, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 95, tlci: 96, cctRange: { minK: 2000, maxK: 6000 }, hasColourMixing: true },
    beam: { angleDeg: 270 },
    weightKg: 1.6,
  },
  {
    seedKey: 'quasar-crossfade',
    manufacturer: 'Quasar Science',
    model: 'Crossfade',
    category: 'LED Tube',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 65,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 65,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1350, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 95, tlci: 95, cctRange: { minK: 2000, maxK: 6000 } },
    beam: { angleDeg: 240 },
    weightKg: 1.3,
  },

  // ---------------------------------------------------------------------------
  // DMG (Rosco)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'dmg-mix-sl1',
    manufacturer: 'DMG (Rosco)',
    model: 'MIX (SL1)',
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
          { offset: 6, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 230,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 230,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 10500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 1700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 115 },
    weightKg: 3.0,
  },
  {
    seedKey: 'dmg-maxi-mix',
    manufacturer: 'DMG (Rosco)',
    model: 'MAXI MIX',
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
          { offset: 6, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 700,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 700,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 19500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 1700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 115 },
    weightKg: 8.5,
  },
  {
    seedKey: 'dmg-mini-mix',
    manufacturer: 'DMG (Rosco)',
    model: 'MINI MIX',
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
          { offset: 6, resolution: 8, attribute: 'lime', label: 'Lime' },
          { offset: 7, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 8, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 9, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 10, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 115,
      },
      {
        name: 'CCT',
        channelCount: 4,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 3, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 115,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 6200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 97, cctRange: { minK: 1700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 115 },
    weightKg: 1.6,
  },

  // ---------------------------------------------------------------------------
  // Kino Flo
  // ---------------------------------------------------------------------------
  {
    seedKey: 'kinoflo-celeb-450-dmx',
    manufacturer: 'Kino Flo',
    model: 'Celeb 450 DMX',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 300,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5300, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 92, cctRange: { minK: 2700, maxK: 5500 } },
    beam: { angleDeg: 120 },
    weightKg: 8.6,
  },
  {
    seedKey: 'kinoflo-diva-lite-30-led',
    manufacturer: 'Kino Flo',
    model: 'Diva-Lite 30 LED',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Bicolour',
        channelCount: 5,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 4, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 200,
      },
      {
        name: 'Simple',
        channelCount: 2,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
        ]),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3600, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 92, cctRange: { minK: 2700, maxK: 5500 } },
    beam: { angleDeg: 120 },
    weightKg: 4.5,
  },
  {
    seedKey: 'kinoflo-freestyle-31',
    manufacturer: 'Kino Flo',
    model: 'FreeStyle 31',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Full Colour',
        channelCount: 8,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'other', label: 'Dimmer Fine' },
          { offset: 2, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 3, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
          { offset: 4, resolution: 8, attribute: 'other', label: 'Hue' },
          { offset: 5, resolution: 8, attribute: 'other', label: 'Saturation' },
          { offset: 6, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 100,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: intensityFirst([
          { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
          { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
        ]),
        powerW: 100,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3100, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 93, cctRange: { minK: 2500, maxK: 9900 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 2.0,
  },
];

const ALL_SEEDS: FixtureSeed[] = [
  ...SEED,
  ...ARRI_SEEDS,
  ...APUTURE_SEEDS,
  ...ASTERA_SEEDS,
  ...NANLUX_SEEDS,
  ...NANLITE_SEEDS,
  ...GODOX_SEEDS,
  ...OTHER_SEEDS,
];

export function seedFixtures(): Fixture[] {
  const stamp = now();
  return ALL_SEEDS.map(({ seedKey, ...rest }) => ({
    ...rest,
    id: `fx-${seedKey}` as FixtureId,
    schemaVersion: 1,
    userModified: false,
    source: { origin: 'curated' as const },
    createdAt: stamp,
    updatedAt: stamp,
  }));
}
