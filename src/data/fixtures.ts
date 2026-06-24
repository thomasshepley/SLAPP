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
  {
    seedKey: 'arri-skypanel-s60c',
    manufacturer: 'ARRI',
    model: 'SkyPanel S60-C',
    category: 'LED Softlight',
    modes: [
      { name: 'Standard (RGBW)', channelCount: 11, channels: intensityFirst(), powerW: 450 },
      { name: 'CCT + Tint', channelCount: 6, channels: intensityFirst(), powerW: 450 },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 14500, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 95, tlci: 90, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 105 },
    weightKg: 14.5,
  },
  {
    seedKey: 'aputure-ls-600d-pro',
    manufacturer: 'Aputure',
    model: 'LS 600d Pro',
    category: 'LED Fresnel/COB',
    modes: [{ name: 'Intensity', channelCount: 4, channels: intensityFirst(), powerW: 720 }],
    photometry: {
      // With hyper reflector, daylight; falls off hard without it.
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 52000, dimmingCurve: { type: 'square' } },
    },
    colour: { cri: 96, tlci: 96, nativeCct: 5600 },
    beam: { angleDeg: 15, fieldAngleDeg: 45 },
    weightKg: 8.5,
  },
  {
    seedKey: 'astera-titan-tube',
    manufacturer: 'Astera',
    model: 'Titan Tube',
    category: 'LED Tube',
    modes: [
      { name: '16ch', channelCount: 16, channels: intensityFirst(), powerW: 72 },
      { name: 'HSI', channelCount: 5, channels: intensityFirst(), powerW: 72 },
    ],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1300, dimmingCurve: { type: 'scurve' } },
    },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 1750, maxK: 20000 }, hasColourMixing: true },
    beam: { angleDeg: 180 },
    weightKg: 1.5,
  },
  {
    seedKey: 'litepanels-gemini-2x1',
    manufacturer: 'Litepanels',
    model: 'Gemini 2x1 Hard',
    category: 'LED Softlight',
    modes: [{ name: 'RGBWW', channelCount: 12, channels: intensityFirst(), powerW: 325 }],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 11000, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 2700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 6.4,
  },
  {
    seedKey: 'aputure-mc',
    manufacturer: 'Aputure',
    model: 'MC',
    category: 'LED Mini Panel',
    modes: [{ name: 'RGBWW', channelCount: 7, channels: intensityFirst(), powerW: 5 }],
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1100, dimmingCurve: { type: 'linear' } },
    },
    colour: { cri: 96, tlci: 96, cctRange: { minK: 3200, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 0.13,
  },
  {
    seedKey: 'etc-s4-led-s3-profile',
    manufacturer: 'ETC',
    model: 'Source Four LED Series 3 (Lustr)',
    category: 'LED Profile',
    modes: [{ name: 'Direct', channelCount: 11, channels: intensityFirst(), powerW: 210 }],
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
