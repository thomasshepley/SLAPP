import { DEFAULT_PHOTOMETRY_KEY } from '@/models/fixture';
import type { FixtureSeed } from './seed-helpers';
import { dimmerOnly, rgbwExtChannels, cctChannels } from './seed-helpers';

export const ARRI_SEEDS: FixtureSeed[] = [
  // ---------------------------------------------------------------------------
  // SkyPanel X-Series
  // ---------------------------------------------------------------------------
  {
    seedKey: 'arri-skypanel-x61',
    manufacturer: 'ARRI',
    model: 'SkyPanel X61',
    category: 'LED Softlight',
    modes: [
      {
        name: 'Standard (RGBW)',
        channelCount: 9,
        channels: rgbwExtChannels(),
        powerW: 800,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 48000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 91, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 22.0,
  },

  // ---------------------------------------------------------------------------
  // L-Series LED Fresnel (DT — Daylight/Tungsten fixed-CCT)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'arri-l5-dt',
    manufacturer: 'ARRI',
    model: 'L5-DT',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 120,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 6200, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 94, tlci: 90, nativeCct: 2800 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 50 } },
    weightKg: 5.2,
  },
  {
    seedKey: 'arri-l7-dt',
    manufacturer: 'ARRI',
    model: 'L7-DT',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 210,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 13000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 94, tlci: 90, nativeCct: 2800 },
    beam: { zoomRangeDeg: { minDeg: 16, maxDeg: 49 } },
    weightKg: 6.7,
  },
  {
    seedKey: 'arri-l10-dt',
    manufacturer: 'ARRI',
    model: 'L10-DT',
    category: 'LED Fresnel',
    modes: [
      {
        name: 'CCT',
        channelCount: 3,
        channels: cctChannels(),
        powerW: 330,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 26000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 94, tlci: 90, nativeCct: 2800 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 50 } },
    weightKg: 12.0,
  },

  // ---------------------------------------------------------------------------
  // Classic Tungsten Fresnels
  // ---------------------------------------------------------------------------
  {
    seedKey: 'arri-150',
    manufacturer: 'ARRI',
    model: 'ARRI 150',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 150,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1200, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { angleDeg: 18 },
    weightKg: 0.8,
  },
  {
    seedKey: 'arri-300-plus',
    manufacturer: 'ARRI',
    model: 'ARRI 300 Plus',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 300,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 4500, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 12, maxDeg: 52 } },
    weightKg: 1.3,
  },
  {
    seedKey: 'arri-650-plus',
    manufacturer: 'ARRI',
    model: 'ARRI 650 Plus',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 650,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 10000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 12, maxDeg: 54 } },
    weightKg: 1.8,
  },
  {
    seedKey: 'arri-1k-plus',
    manufacturer: 'ARRI',
    model: 'ARRI 1K Plus',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 1000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 21000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 12, maxDeg: 52 } },
    weightKg: 2.5,
  },
  {
    seedKey: 'arri-2k',
    manufacturer: 'ARRI',
    model: 'ARRI 2K',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 2000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 55000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 12, maxDeg: 54 } },
    weightKg: 5.5,
  },
  {
    seedKey: 'arri-t1',
    manufacturer: 'ARRI',
    model: 'ARRI T1',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 1000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 20000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 12, maxDeg: 52 } },
    weightKg: 5.0,
  },
  {
    seedKey: 'arri-t2',
    manufacturer: 'ARRI',
    model: 'ARRI T2',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 2000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 52000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 12, maxDeg: 54 } },
    weightKg: 10.0,
  },
  {
    seedKey: 'arri-t5',
    manufacturer: 'ARRI',
    model: 'ARRI T5',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 5000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 130000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 12, maxDeg: 54 } },
    weightKg: 19.0,
  },
  {
    seedKey: 'arri-t12',
    manufacturer: 'ARRI',
    model: 'ARRI T12',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 12000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 300000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 60 } },
    weightKg: 28.0,
  },
  {
    seedKey: 'arri-t24',
    manufacturer: 'ARRI',
    model: 'ARRI T24',
    category: 'Tungsten Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 24000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 600000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 60 } },
    weightKg: 45.0,
  },

  // ---------------------------------------------------------------------------
  // HMI Fresnel (Daylight-balanced)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'arri-compact-200',
    manufacturer: 'ARRI',
    model: 'ARRI Compact 200',
    category: 'HMI Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 8000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 20, maxDeg: 58 } },
    weightKg: 3.5,
  },
  {
    seedKey: 'arri-d5',
    manufacturer: 'ARRI',
    model: 'ARRI D5',
    category: 'HMI Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 575,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 25000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 52 } },
    weightKg: 7.5,
  },
  {
    seedKey: 'arri-d12',
    manufacturer: 'ARRI',
    model: 'ARRI D12',
    category: 'HMI Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 1200,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 55000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 52 } },
    weightKg: 10.0,
  },
  {
    seedKey: 'arri-d25',
    manufacturer: 'ARRI',
    model: 'ARRI D25',
    category: 'HMI Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 2500,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 100000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 52 } },
    weightKg: 17.0,
  },
  {
    seedKey: 'arri-d40',
    manufacturer: 'ARRI',
    model: 'ARRI D40',
    category: 'HMI Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 4000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 170000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 52 } },
    weightKg: 29.0,
  },
  {
    seedKey: 'arri-m8',
    manufacturer: 'ARRI',
    model: 'ARRI M8',
    category: 'HMI Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 800,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 32000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 52 } },
    weightKg: 8.0,
  },
  {
    seedKey: 'arri-m18',
    manufacturer: 'ARRI',
    model: 'ARRI M18',
    category: 'HMI Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 1800,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 75000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 52 } },
    weightKg: 15.0,
  },
  {
    seedKey: 'arri-m40',
    manufacturer: 'ARRI',
    model: 'ARRI M40',
    category: 'HMI Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 4000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 180000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 52 } },
    weightKg: 32.0,
  },
  {
    seedKey: 'arri-m90',
    manufacturer: 'ARRI',
    model: 'ARRI M90',
    category: 'HMI Fresnel',
    modes: [
      {
        name: 'Dimmer',
        channelCount: 1,
        channels: dimmerOnly(),
        powerW: 9000,
      },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 350000, dimmingCurve: { type: 'linear' } },
    },
    colour: { nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 52 } },
    weightKg: 47.0,
  },
];
