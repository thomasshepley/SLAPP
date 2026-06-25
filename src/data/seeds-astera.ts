import { DEFAULT_PHOTOMETRY_KEY } from '@/models/fixture';
import type { FixtureSeed } from './seed-helpers';
import { intensityFirst, rgbwChannels, pixelTubeChannels, hsiChannels } from './seed-helpers';

/**
 * Astera fixture seeds — battery-powered RGBMA LED fixtures.
 *
 * Skipped (already in main seed list):
 *   Titan Tube, Helios Tube, HydraPanel, PixelBrick,
 *   AX1 PixelTube, AX3 LightDrop, NYX Bulb, LeoFresnel
 */

const asteraRgbmaChannels = () =>
  rgbwChannels([
    { offset: 5, resolution: 8, attribute: 'amber', label: 'Amber' },
    { offset: 6, resolution: 8, attribute: 'control', label: 'Control' },
  ]);

const asteraCctChannels = () =>
  intensityFirst([
    { offset: 1, resolution: 8, attribute: 'cct', label: 'CCT' },
    { offset: 2, resolution: 8, attribute: 'control', label: 'Control' },
  ]);

export const ASTERA_SEEDS: FixtureSeed[] = [
  // ---------------------------------------------------------------------------
  // AX5 TriplePAR
  // ---------------------------------------------------------------------------
  {
    seedKey: 'astera-ax5-triplepar',
    manufacturer: 'Astera',
    model: 'AX5 TriplePAR',
    category: 'LED PAR',
    modes: [
      {
        name: 'RGBMA',
        channelCount: 7,
        channels: asteraRgbmaChannels(),
        powerW: 45,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: asteraCctChannels(),
        powerW: 45,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 21 },
    weightKg: 2.3,
  },

  // ---------------------------------------------------------------------------
  // AX9 PowerPAR
  // ---------------------------------------------------------------------------
  {
    seedKey: 'astera-ax9-powerpar',
    manufacturer: 'Astera',
    model: 'AX9 PowerPAR',
    category: 'LED PAR',
    modes: [
      {
        name: 'RGBMA',
        channelCount: 7,
        channels: asteraRgbmaChannels(),
        powerW: 135,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: asteraCctChannels(),
        powerW: 135,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 98, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 21 },
    weightKg: 4.8,
  },

  // ---------------------------------------------------------------------------
  // AX10 SpotMax
  // ---------------------------------------------------------------------------
  {
    seedKey: 'astera-ax10-spotmax',
    manufacturer: 'Astera',
    model: 'AX10 SpotMax',
    category: 'LED Spot',
    modes: [
      {
        name: 'RGBMA',
        channelCount: 7,
        channels: asteraRgbmaChannels(),
        powerW: 185,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: asteraCctChannels(),
        powerW: 185,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 16000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 98, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 12 },
    weightKg: 6.5,
  },

  // ---------------------------------------------------------------------------
  // PlutoFresnel
  // ---------------------------------------------------------------------------
  {
    seedKey: 'astera-plutofresnel',
    manufacturer: 'Astera',
    model: 'PlutoFresnel',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'RGBMA',
        channelCount: 7,
        channels: asteraRgbmaChannels(),
        powerW: 72,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: asteraCctChannels(),
        powerW: 72,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 6500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 55 } },
    weightKg: 3.0,
  },

  // ---------------------------------------------------------------------------
  // PlutoFlood
  // ---------------------------------------------------------------------------
  {
    seedKey: 'astera-plutoflood',
    manufacturer: 'Astera',
    model: 'PlutoFlood',
    category: 'LED Flood',
    modes: [
      {
        name: 'RGBMA',
        channelCount: 7,
        channels: asteraRgbmaChannels(),
        powerW: 72,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: asteraCctChannels(),
        powerW: 72,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 2.8,
  },

  // ---------------------------------------------------------------------------
  // MeteorLite
  // ---------------------------------------------------------------------------
  {
    seedKey: 'astera-meteorlite',
    manufacturer: 'Astera',
    model: 'MeteorLite',
    category: 'LED Puck',
    modes: [
      {
        name: 'RGBMA',
        channelCount: 7,
        channels: asteraRgbmaChannels(),
        powerW: 15,
      },
      {
        name: 'CCT',
        channelCount: 3,
        channels: asteraCctChannels(),
        powerW: 15,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 800, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 0.3,
  },
];
