import { DEFAULT_PHOTOMETRY_KEY } from '@/models/fixture';
import type { FixtureSeed } from './seed-helpers';
import { intensityFirst, dimmerOnly, cctChannels, rgbwChannels, pixelTubeChannels } from './seed-helpers';

export const OTHER_SEEDS: FixtureSeed[] = [
  // ---------------------------------------------------------------------------
  // Litepanels
  // ---------------------------------------------------------------------------
  {
    seedKey: 'litepanels-astra-3x',
    manufacturer: 'Litepanels',
    model: 'Astra 3X Bi-Color',
    category: 'LED Panel',
    modes: [{ name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 63 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 4800, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 93, cctRange: { minK: 3200, maxK: 6300 } },
    beam: { angleDeg: 75 },
    weightKg: 2.0,
  },
  {
    seedKey: 'litepanels-astra-1x1-soft',
    manufacturer: 'Litepanels',
    model: 'Astra 1x1 Soft Bi-Color',
    category: 'LED Panel',
    modes: [{ name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 105 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3800, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 92, cctRange: { minK: 3200, maxK: 6300 } },
    beam: { angleDeg: 90 },
    weightKg: 2.7,
  },
  {
    seedKey: 'litepanels-gemini-2x1-soft',
    manufacturer: 'Litepanels',
    model: 'Gemini 2x1 Soft Panel',
    category: 'LED Panel',
    modes: [
      { name: 'Full Color (RGBWW)', channelCount: 9, channels: rgbwChannels([
        { offset: 5, resolution: 8, attribute: 'cct', label: 'CCT' },
        { offset: 6, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
        { offset: 7, resolution: 8, attribute: 'other', label: 'Effect' },
        { offset: 8, resolution: 8, attribute: 'control', label: 'Control' },
      ]), powerW: 325 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 325 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5100, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 98, tlci: 97, cctRange: { minK: 2700, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 11.8,
  },

  // ---------------------------------------------------------------------------
  // Creamsource
  // ---------------------------------------------------------------------------
  {
    seedKey: 'creamsource-micro-colour',
    manufacturer: 'Creamsource',
    model: 'Micro Colour',
    category: 'LED Panel',
    modes: [
      { name: 'RGBW', channelCount: 5, channels: rgbwChannels(), powerW: 125 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 125 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3200, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 93, cctRange: { minK: 2200, maxK: 15000 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 2.5,
  },
  {
    seedKey: 'creamsource-doppio',
    manufacturer: 'Creamsource',
    model: 'Doppio',
    category: 'LED Panel',
    modes: [
      { name: 'RGBW', channelCount: 5, channels: rgbwChannels(), powerW: 250 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 250 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 6500, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2200, maxK: 15000 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 5.5,
  },
  {
    seedKey: 'creamsource-vortex4-mini',
    manufacturer: 'Creamsource',
    model: 'Vortex4 Mini',
    category: 'LED Panel',
    modes: [
      { name: 'RGBW', channelCount: 5, channels: rgbwChannels(), powerW: 200 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 200 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5800, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 97, tlci: 96, cctRange: { minK: 2200, maxK: 15000 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 4.5,
  },

  // ---------------------------------------------------------------------------
  // Quasar Science
  // ---------------------------------------------------------------------------
  {
    seedKey: 'quasar-q-lion',
    manufacturer: 'Quasar Science',
    model: 'Q-Lion',
    category: 'LED Tube',
    modes: [
      { name: 'RGBX', channelCount: 8, channels: pixelTubeChannels(), powerW: 25 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 850, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 95, cctRange: { minK: 2000, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.45,
  },
  {
    seedKey: 'quasar-q50',
    manufacturer: 'Quasar Science',
    model: 'Q50',
    category: 'LED Tube',
    modes: [
      { name: 'RGBX', channelCount: 8, channels: pixelTubeChannels(), powerW: 50 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2800, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2000, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 1.1,
  },
  {
    seedKey: 'quasar-rainbow-2-rr50',
    manufacturer: 'Quasar Science',
    model: 'Rainbow 2 RR50',
    category: 'LED Tube',
    modes: [
      { name: 'RGBX', channelCount: 8, channels: pixelTubeChannels(), powerW: 25 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1500, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 94, cctRange: { minK: 2000, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 360 },
    weightKg: 0.5,
  },

  // ---------------------------------------------------------------------------
  // DMG Lumière
  // ---------------------------------------------------------------------------
  {
    seedKey: 'dmg-mix-sl1-plus',
    manufacturer: 'DMG Lumière',
    model: 'SL1 Mix+',
    category: 'LED Panel',
    modes: [
      { name: 'Full Color', channelCount: 5, channels: rgbwChannels(), powerW: 220 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 220 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5800, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 97, tlci: 96, cctRange: { minK: 2200, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 5.0,
  },
  {
    seedKey: 'dmg-mini-switch',
    manufacturer: 'DMG Lumière',
    model: 'MINI Switch',
    category: 'LED Panel',
    modes: [
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 40 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1600, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 93, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 110 },
    weightKg: 0.8,
  },
  {
    seedKey: 'dmg-dash-pocket',
    manufacturer: 'DMG Lumière',
    model: 'DASH Pocket',
    category: 'LED Panel',
    modes: [
      { name: 'Full Color', channelCount: 5, channels: rgbwChannels(), powerW: 35 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1400, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2200, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 110 },
    weightKg: 0.6,
  },

  // ---------------------------------------------------------------------------
  // Kino Flo
  // ---------------------------------------------------------------------------
  {
    seedKey: 'kinoflo-celeb-850-dmx',
    manufacturer: 'Kino Flo',
    model: 'Celeb 850 LED DMX',
    category: 'LED Softlight',
    modes: [
      { name: 'Full Color', channelCount: 9, channels: rgbwChannels([
        { offset: 5, resolution: 8, attribute: 'cct', label: 'CCT' },
        { offset: 6, resolution: 8, attribute: 'tint', label: 'Green-Magenta' },
        { offset: 7, resolution: 8, attribute: 'other', label: 'Gel' },
        { offset: 8, resolution: 8, attribute: 'control', label: 'Control' },
      ]), powerW: 440 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 440 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 6200, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 92, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 10.0,
  },
  {
    seedKey: 'kinoflo-select-30',
    manufacturer: 'Kino Flo',
    model: 'Select 30',
    category: 'LED Softlight',
    modes: [
      { name: 'Full Color', channelCount: 5, channels: rgbwChannels(), powerW: 170 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 170 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 4200, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 92, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 3.5,
  },
  {
    seedKey: 'kinoflo-select-20',
    manufacturer: 'Kino Flo',
    model: 'Select 20',
    category: 'LED Softlight',
    modes: [
      { name: 'Full Color', channelCount: 5, channels: rgbwChannels(), powerW: 98 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 98 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2800, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 92, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 2.0,
  },
  {
    seedKey: 'kinoflo-freestyle-21',
    manufacturer: 'Kino Flo',
    model: 'FreeStyle 21 LED',
    category: 'LED Softlight',
    modes: [
      { name: 'Full Color', channelCount: 5, channels: rgbwChannels(), powerW: 92 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 92 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2500, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 92, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 2.6,
  },
  {
    seedKey: 'kinoflo-diva-lite-21-led',
    manufacturer: 'Kino Flo',
    model: 'Diva-Lite 21 LED DMX',
    category: 'LED Softlight',
    modes: [
      { name: 'Full Color', channelCount: 5, channels: rgbwChannels(), powerW: 108 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 108 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3000, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 92, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 100 },
    weightKg: 3.2,
  },

  // ---------------------------------------------------------------------------
  // ETC
  // ---------------------------------------------------------------------------
  {
    seedKey: 'etc-source-four-led-s2-lustr',
    manufacturer: 'ETC',
    model: 'Source Four LED Series 2 Lustr',
    category: 'LED Profile',
    modes: [
      { name: 'Direct (7ch)', channelCount: 7, channels: intensityFirst([
        { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
        { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
        { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
        { offset: 4, resolution: 8, attribute: 'white', label: 'White' },
        { offset: 5, resolution: 8, attribute: 'amber', label: 'Amber' },
        { offset: 6, resolution: 8, attribute: 'lime', label: 'Lime' },
      ]), powerW: 160 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 160 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 7200, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 92, tlci: 85, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 25, maxDeg: 50 } },
    weightKg: 7.5,
  },
  {
    seedKey: 'etc-colorsource-par',
    manufacturer: 'ETC',
    model: 'ColorSource PAR',
    category: 'LED PAR',
    modes: [
      { name: 'Direct', channelCount: 5, channels: rgbwChannels(), powerW: 90 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2200, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 92, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 32 },
    weightKg: 4.0,
  },
  {
    seedKey: 'etc-colorsource-spot-jr',
    manufacturer: 'ETC',
    model: 'ColorSource Spot jr',
    category: 'LED Profile',
    modes: [
      { name: 'Direct', channelCount: 5, channels: rgbwChannels(), powerW: 50 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1500, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 92, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 25, maxDeg: 50 } },
    weightKg: 5.0,
  },
  {
    seedKey: 'etc-fos-4-panel',
    manufacturer: 'ETC',
    model: 'fos/4 Panel',
    category: 'LED Panel',
    modes: [
      { name: 'Direct (7ch)', channelCount: 7, channels: intensityFirst([
        { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
        { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
        { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
        { offset: 4, resolution: 8, attribute: 'white', label: 'White' },
        { offset: 5, resolution: 8, attribute: 'amber', label: 'Amber' },
        { offset: 6, resolution: 8, attribute: 'lime', label: 'Lime' },
      ]), powerW: 340 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 340 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5200, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 90, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 90 },
    weightKg: 8.5,
  },
  {
    seedKey: 'etc-fos-4-fresnel',
    manufacturer: 'ETC',
    model: 'fos/4 Fresnel',
    category: 'LED Fresnel',
    modes: [
      { name: 'Direct (7ch)', channelCount: 7, channels: intensityFirst([
        { offset: 1, resolution: 8, attribute: 'red', label: 'Red' },
        { offset: 2, resolution: 8, attribute: 'green', label: 'Green' },
        { offset: 3, resolution: 8, attribute: 'blue', label: 'Blue' },
        { offset: 4, resolution: 8, attribute: 'white', label: 'White' },
        { offset: 5, resolution: 8, attribute: 'amber', label: 'Amber' },
        { offset: 6, resolution: 8, attribute: 'lime', label: 'Lime' },
      ]), powerW: 300 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 8500, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, tlci: 90, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 15, maxDeg: 80 } },
    weightKg: 9.0,
  },

  // ---------------------------------------------------------------------------
  // Rotolight
  // ---------------------------------------------------------------------------
  {
    seedKey: 'rotolight-titan-x2',
    manufacturer: 'Rotolight',
    model: 'TITAN X2',
    category: 'LED Panel',
    modes: [
      { name: 'Full Color', channelCount: 5, channels: rgbwChannels(), powerW: 500 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 500 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 13500, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2300, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 55 },
    weightKg: 9.5,
  },
  {
    seedKey: 'rotolight-neo-3-pro',
    manufacturer: 'Rotolight',
    model: 'NEO 3 Pro',
    category: 'LED Panel',
    modes: [
      { name: 'Full Color', channelCount: 5, channels: rgbwChannels(), powerW: 58 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 58 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 2950, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2300, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 50 },
    weightKg: 1.1,
  },
  {
    seedKey: 'rotolight-aeos-2-pro',
    manufacturer: 'Rotolight',
    model: 'AEOS 2 Pro',
    category: 'LED Panel',
    modes: [
      { name: 'Full Color', channelCount: 5, channels: rgbwChannels(), powerW: 115 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 115 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 5100, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2300, maxK: 10000 }, hasColourMixing: true },
    beam: { angleDeg: 55 },
    weightKg: 1.4,
  },

  // ---------------------------------------------------------------------------
  // Dedolight
  // ---------------------------------------------------------------------------
  {
    seedKey: 'dedolight-dled7-d',
    manufacturer: 'Dedolight',
    model: 'DLED7-D Daylight',
    category: 'LED Focusing',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 90 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 28000, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 4, maxDeg: 60 } },
    weightKg: 1.1,
  },
  {
    seedKey: 'dedolight-dled7-bi',
    manufacturer: 'Dedolight',
    model: 'DLED7-Bi Bi-Color',
    category: 'LED Focusing',
    modes: [{ name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 90 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 22000, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { zoomRangeDeg: { minDeg: 4, maxDeg: 60 } },
    weightKg: 1.1,
  },
  {
    seedKey: 'dedolight-dled4-d',
    manufacturer: 'Dedolight',
    model: 'DLED4-D Daylight',
    category: 'LED Focusing',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 40 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 14000, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 95, nativeCct: 5600 },
    beam: { zoomRangeDeg: { minDeg: 4, maxDeg: 60 } },
    weightKg: 0.5,
  },

  // ---------------------------------------------------------------------------
  // BB&S (Bron)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'bbs-area-48-soft',
    manufacturer: 'BB&S',
    model: 'Area 48 Soft',
    category: 'LED Softlight',
    modes: [{ name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 130 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3200, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 97, tlci: 96, cctRange: { minK: 2700, maxK: 6500 } },
    beam: { angleDeg: 100 },
    weightKg: 3.7,
  },
  {
    seedKey: 'bbs-pipeline-reflect',
    manufacturer: 'BB&S',
    model: 'Pipeline Reflect',
    category: 'LED Tube',
    modes: [
      { name: 'RGBWW', channelCount: 8, channels: pixelTubeChannels(), powerW: 23 },
      { name: 'CCT', channelCount: 3, channels: cctChannels(), powerW: 23 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 1100, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 96, tlci: 95, cctRange: { minK: 2700, maxK: 6500 }, hasColourMixing: true },
    beam: { angleDeg: 120 },
    weightKg: 0.6,
  },

  // ---------------------------------------------------------------------------
  // Mole-Richardson (legacy tungsten, still on every truck)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'mole-1k-junior',
    manufacturer: 'Mole-Richardson',
    model: '1K Baby Junior',
    category: 'Tungsten Fresnel',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 1000 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 20000, dimmingCurve: { type: 'linear' } } },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 14, maxDeg: 56 } },
    weightKg: 4.5,
  },
  {
    seedKey: 'mole-2k-junior',
    manufacturer: 'Mole-Richardson',
    model: '2K Junior',
    category: 'Tungsten Fresnel',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 2000 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 45000, dimmingCurve: { type: 'linear' } } },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 14, maxDeg: 56 } },
    weightKg: 7.5,
  },
  {
    seedKey: 'mole-5k-senior',
    manufacturer: 'Mole-Richardson',
    model: '5K Senior',
    category: 'Tungsten Fresnel',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 5000 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 125000, dimmingCurve: { type: 'linear' } } },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 14, maxDeg: 56 } },
    weightKg: 15.0,
  },
  {
    seedKey: 'mole-10k-tener',
    manufacturer: 'Mole-Richardson',
    model: '10K Tener',
    category: 'Tungsten Fresnel',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 10000 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 250000, dimmingCurve: { type: 'linear' } } },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 14, maxDeg: 56 } },
    weightKg: 23.0,
  },
  {
    seedKey: 'mole-2k-zip-softlite',
    manufacturer: 'Mole-Richardson',
    model: '2K Zip Softlite',
    category: 'Tungsten Softlight',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 2000 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 3200, dimmingCurve: { type: 'linear' } } },
    colour: { nativeCct: 3200 },
    beam: { angleDeg: 120 },
    weightKg: 8.0,
  },
  {
    seedKey: 'mole-4k-zip-softlite',
    manufacturer: 'Mole-Richardson',
    model: '4K Zip Softlite',
    category: 'Tungsten Softlight',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 4000 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 6500, dimmingCurve: { type: 'linear' } } },
    colour: { nativeCct: 3200 },
    beam: { angleDeg: 120 },
    weightKg: 14.0,
  },

  // ---------------------------------------------------------------------------
  // Source Four (conventional – still on almost every job)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'etc-source-four-750',
    manufacturer: 'ETC',
    model: 'Source Four 750W',
    category: 'Tungsten Profile',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 750 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 16500, dimmingCurve: { type: 'linear' } } },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 19, maxDeg: 50 } },
    weightKg: 7.3,
  },
  {
    seedKey: 'etc-source-four-575',
    manufacturer: 'ETC',
    model: 'Source Four 575W',
    category: 'Tungsten Profile',
    modes: [{ name: 'Dimmer', channelCount: 1, channels: dimmerOnly(), powerW: 575 }],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 12000, dimmingCurve: { type: 'linear' } } },
    colour: { nativeCct: 3200 },
    beam: { zoomRangeDeg: { minDeg: 19, maxDeg: 50 } },
    weightKg: 7.3,
  },

  // ---------------------------------------------------------------------------
  // Elation (moving lights)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'elation-proteus-maximus',
    manufacturer: 'Elation',
    model: 'Proteus Maximus',
    category: 'LED Moving Head',
    modes: [
      { name: 'Extended', channelCount: 13, channels: intensityFirst([
        { offset: 1, resolution: 16, attribute: 'pan', label: 'Pan' },
        { offset: 3, resolution: 16, attribute: 'tilt', label: 'Tilt' },
        { offset: 5, resolution: 8, attribute: 'zoom', label: 'Zoom' },
        { offset: 6, resolution: 8, attribute: 'focus', label: 'Focus' },
        { offset: 7, resolution: 8, attribute: 'colourWheel', label: 'Colour Wheel' },
        { offset: 8, resolution: 8, attribute: 'gobo', label: 'Gobo 1' },
        { offset: 9, resolution: 8, attribute: 'gobo', label: 'Gobo 2' },
        { offset: 10, resolution: 8, attribute: 'shutter', label: 'Shutter' },
        { offset: 11, resolution: 8, attribute: 'other', label: 'Prism' },
        { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
      ]), powerW: 950 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 135000, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 90, nativeCct: 7500 },
    beam: { zoomRangeDeg: { minDeg: 4, maxDeg: 44 } },
    weightKg: 37.6,
  },
  {
    seedKey: 'elation-proteus-hybrid',
    manufacturer: 'Elation',
    model: 'Proteus Hybrid',
    category: 'LED Moving Head',
    modes: [
      { name: 'Standard', channelCount: 13, channels: intensityFirst([
        { offset: 1, resolution: 16, attribute: 'pan', label: 'Pan' },
        { offset: 3, resolution: 16, attribute: 'tilt', label: 'Tilt' },
        { offset: 5, resolution: 8, attribute: 'zoom', label: 'Zoom' },
        { offset: 6, resolution: 8, attribute: 'focus', label: 'Focus' },
        { offset: 7, resolution: 8, attribute: 'colourWheel', label: 'Colour Wheel' },
        { offset: 8, resolution: 8, attribute: 'gobo', label: 'Gobo 1' },
        { offset: 9, resolution: 8, attribute: 'gobo', label: 'Gobo 2' },
        { offset: 10, resolution: 8, attribute: 'shutter', label: 'Shutter' },
        { offset: 11, resolution: 8, attribute: 'other', label: 'Prism' },
        { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
      ]), powerW: 470 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 85000, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 90, nativeCct: 7500 },
    beam: { zoomRangeDeg: { minDeg: 3, maxDeg: 45 } },
    weightKg: 24.0,
  },

  // ---------------------------------------------------------------------------
  // Martin (moving lights)
  // ---------------------------------------------------------------------------
  {
    seedKey: 'martin-mac-aura-xb',
    manufacturer: 'Martin',
    model: 'MAC Aura XB',
    category: 'LED Moving Head Wash',
    modes: [
      { name: 'Standard', channelCount: 13, channels: intensityFirst([
        { offset: 1, resolution: 16, attribute: 'pan', label: 'Pan' },
        { offset: 3, resolution: 16, attribute: 'tilt', label: 'Tilt' },
        { offset: 5, resolution: 8, attribute: 'zoom', label: 'Zoom' },
        { offset: 6, resolution: 8, attribute: 'red', label: 'Red' },
        { offset: 7, resolution: 8, attribute: 'green', label: 'Green' },
        { offset: 8, resolution: 8, attribute: 'blue', label: 'Blue' },
        { offset: 9, resolution: 8, attribute: 'white', label: 'White' },
        { offset: 10, resolution: 8, attribute: 'cct', label: 'CTC' },
        { offset: 11, resolution: 8, attribute: 'shutter', label: 'Shutter' },
        { offset: 12, resolution: 8, attribute: 'control', label: 'Control' },
      ]), powerW: 320 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 12000, dimmingCurve: { type: 'linear' } } },
    colour: { cri: 85, cctRange: { minK: 2800, maxK: 10000 }, hasColourMixing: true },
    beam: { zoomRangeDeg: { minDeg: 11, maxDeg: 58 } },
    weightKg: 6.5,
  },
  {
    seedKey: 'martin-mac-encore-performance-ww',
    manufacturer: 'Martin',
    model: 'MAC Encore Performance WW',
    category: 'LED Moving Head Profile',
    modes: [
      { name: 'Standard', channelCount: 10, channels: intensityFirst([
        { offset: 1, resolution: 16, attribute: 'pan', label: 'Pan' },
        { offset: 3, resolution: 16, attribute: 'tilt', label: 'Tilt' },
        { offset: 5, resolution: 8, attribute: 'zoom', label: 'Zoom' },
        { offset: 6, resolution: 8, attribute: 'focus', label: 'Focus' },
        { offset: 7, resolution: 8, attribute: 'gobo', label: 'Gobo' },
        { offset: 8, resolution: 8, attribute: 'shutter', label: 'Shutter' },
        { offset: 9, resolution: 8, attribute: 'control', label: 'Control' },
      ]), powerW: 468 },
    ],
    photometry: { [DEFAULT_PHOTOMETRY_KEY]: { luxAt1m: 35000, dimmingCurve: { type: 'linear' } } },
    colour: { nativeCct: 3000 },
    beam: { zoomRangeDeg: { minDeg: 12, maxDeg: 42 } },
    weightKg: 22.5,
  },
];
