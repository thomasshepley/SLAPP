import type { ChannelFunction, Fixture, FixtureMode } from '@/models/fixture';

/**
 * Realistic DMX personality generation.
 *
 * Real fixtures expose many DMX modes — a bare dimmer, colour-mixing formats,
 * 16-bit variants, and (for tubes/bars) a spread of pixel personalities. An
 * Astera Titan Tube alone ships ~20+ modes. Hand-authoring those for every
 * seed entry would be thousands of unmaintainable lines, so instead we derive a
 * plausible personality set from each fixture's colour engine and form factor.
 *
 * These are sensible defaults for patch planning; users import a GDTF for the
 * console-exact channel order when they need it.
 */

type Engine = 'single' | 'cct' | 'rgb' | 'rgbw' | 'rgbwa';

const ch = (
  offset: number,
  attribute: ChannelFunction['attribute'],
  label: string,
  resolution: ChannelFunction['resolution'] = 8,
): ChannelFunction => ({ offset, resolution, attribute, label });

/** Footprint (DMX slots) of a channel list, honouring 16-bit widths. */
function footprint(channels: ChannelFunction[]): number {
  return channels.reduce((max, c) => Math.max(max, c.offset + c.resolution / 8), 0);
}

function mode(name: string, channels: ChannelFunction[], powerW?: number): FixtureMode {
  return { name, channelCount: footprint(channels), channels, powerW };
}

/** One colour "cell" (no master dimmer) for pixel personalities. */
function pixelCell(engine: Engine, base: number, n: number): ChannelFunction[] {
  const tag = ` [${n}]`;
  switch (engine) {
    case 'rgbwa':
      return [
        ch(base, 'red', 'Red' + tag),
        ch(base + 1, 'green', 'Green' + tag),
        ch(base + 2, 'blue', 'Blue' + tag),
        ch(base + 3, 'white', 'White' + tag),
        ch(base + 4, 'amber', 'Amber' + tag),
      ];
    case 'rgbw':
      return [
        ch(base, 'red', 'Red' + tag),
        ch(base + 1, 'green', 'Green' + tag),
        ch(base + 2, 'blue', 'Blue' + tag),
        ch(base + 3, 'white', 'White' + tag),
      ];
    default: // rgb
      return [
        ch(base, 'red', 'Red' + tag),
        ch(base + 1, 'green', 'Green' + tag),
        ch(base + 2, 'blue', 'Blue' + tag),
      ];
  }
}

const cellWidth: Record<Engine, number> = { single: 1, cct: 2, rgb: 3, rgbw: 4, rgbwa: 5 };

/** Static (single-cell) personalities for a colour engine. */
function staticModes(engine: Engine, powerW?: number): FixtureMode[] {
  const dim = mode('Dimmer', [ch(0, 'intensity', 'Dimmer')], powerW);
  const dim16 = mode('Dimmer 16-bit', [ch(0, 'intensity', 'Dimmer', 16)], powerW);

  switch (engine) {
    case 'single':
      return [dim, dim16];

    case 'cct':
      return [
        dim,
        mode('CCT', [ch(0, 'intensity', 'Dimmer'), ch(1, 'cct', 'CCT')], powerW),
        mode('CCT + Green/Magenta', [ch(0, 'intensity', 'Dimmer'), ch(1, 'cct', 'CCT'), ch(2, 'tint', 'Green-Magenta')], powerW),
        mode('CCT 16-bit', [ch(0, 'intensity', 'Dimmer', 16), ch(2, 'cct', 'CCT', 16)], powerW),
      ];

    case 'rgb':
      return [
        dim,
        mode('RGB', [ch(0, 'red', 'Red'), ch(1, 'green', 'Green'), ch(2, 'blue', 'Blue')], powerW),
        mode('RGB + Dimmer', [ch(0, 'intensity', 'Dimmer'), ch(1, 'red', 'Red'), ch(2, 'green', 'Green'), ch(3, 'blue', 'Blue')], powerW),
        mode('HSI', [ch(0, 'intensity', 'Intensity'), ch(1, 'other', 'Hue'), ch(2, 'other', 'Saturation')], powerW),
        mode('CCT', [ch(0, 'intensity', 'Dimmer'), ch(1, 'cct', 'CCT')], powerW),
      ];

    case 'rgbw':
      return [
        dim,
        mode('RGBW', [ch(0, 'red', 'Red'), ch(1, 'green', 'Green'), ch(2, 'blue', 'Blue'), ch(3, 'white', 'White')], powerW),
        mode('RGBW + Dimmer', [ch(0, 'intensity', 'Dimmer'), ch(1, 'red', 'Red'), ch(2, 'green', 'Green'), ch(3, 'blue', 'Blue'), ch(4, 'white', 'White')], powerW),
        mode('RGB', [ch(0, 'red', 'Red'), ch(1, 'green', 'Green'), ch(2, 'blue', 'Blue')], powerW),
        mode('HSI', [ch(0, 'intensity', 'Intensity'), ch(1, 'other', 'Hue'), ch(2, 'other', 'Saturation')], powerW),
        mode('CCT + Green/Magenta', [ch(0, 'intensity', 'Dimmer'), ch(1, 'cct', 'CCT'), ch(2, 'tint', 'Green-Magenta')], powerW),
        mode('RGBW 16-bit', [ch(0, 'intensity', 'Dimmer', 16), ch(2, 'red', 'Red', 16), ch(4, 'green', 'Green', 16), ch(6, 'blue', 'Blue', 16), ch(8, 'white', 'White', 16)], powerW),
      ];

    case 'rgbwa':
      return [
        dim,
        mode('RGBWA', [ch(0, 'red', 'Red'), ch(1, 'green', 'Green'), ch(2, 'blue', 'Blue'), ch(3, 'white', 'White'), ch(4, 'amber', 'Amber')], powerW),
        mode('RGBWA + Dimmer', [ch(0, 'intensity', 'Dimmer'), ch(1, 'red', 'Red'), ch(2, 'green', 'Green'), ch(3, 'blue', 'Blue'), ch(4, 'white', 'White'), ch(5, 'amber', 'Amber')], powerW),
        mode('RGB', [ch(0, 'red', 'Red'), ch(1, 'green', 'Green'), ch(2, 'blue', 'Blue')], powerW),
        mode('HSI', [ch(0, 'intensity', 'Intensity'), ch(1, 'other', 'Hue'), ch(2, 'other', 'Saturation')], powerW),
        mode('CCT + Green/Magenta', [ch(0, 'intensity', 'Dimmer'), ch(1, 'cct', 'CCT'), ch(2, 'tint', 'Green-Magenta')], powerW),
        mode('RGBWA 16-bit', [ch(0, 'intensity', 'Dimmer', 16), ch(2, 'red', 'Red', 16), ch(4, 'green', 'Green', 16), ch(6, 'blue', 'Blue', 16), ch(8, 'white', 'White', 16), ch(10, 'amber', 'Amber', 16)], powerW),
      ];
  }
}

/** Pixel personalities: master dimmer + N repeated colour cells. */
function pixelModes(engine: Engine, maxPixels: number, powerW?: number): FixtureMode[] {
  if (maxPixels < 2 || engine === 'single' || engine === 'cct') return [];
  const width = cellWidth[engine];
  const tiers = [2, 4, 8, 16].filter((p) => p <= maxPixels);
  const label = engine.toUpperCase();
  return tiers.map((pixels) => {
    const channels: ChannelFunction[] = [ch(0, 'intensity', 'Master Dimmer')];
    for (let i = 0; i < pixels; i++) {
      channels.push(...pixelCell(engine, 1 + i * width, i + 1));
    }
    return mode(`Pixel ${pixels}-cell (${label})`, channels, powerW);
  });
}

// --- Deriving a fixture's engine + form factor --------------------------------

function detectEngine(f: Fixture): Engine {
  const attrs = new Set(f.modes.flatMap((m) => m.channels.map((c) => c.attribute)));
  if (f.colour.hasColourMixing) {
    if (attrs.has('amber') || f.manufacturer === 'Astera') return 'rgbwa';
    if (attrs.has('white') || attrs.has('red')) return 'rgbw';
    return 'rgb';
  }
  if (f.colour.cctRange) return 'cct';
  return 'single';
}

const PIXEL_RE = /tube|pavotube|infinibar|pixelbrick|pixelbar|titan|helios|ax1|ax3|rainbow|pipeline|mixwand|\bt8\b|bar\b|stick|wand/i;

function detectMaxPixels(f: Fixture): number {
  if (!f.colour.hasColourMixing) return 0;
  const hay = `${f.model} ${f.category ?? ''}`;
  if (!PIXEL_RE.test(hay)) return 0;
  // Long/hero tubes address 16 cells; shorter tubes/bars 8.
  if (/titan|helios|infinibar|pixelbrick|rainbow|4ft|4'|pt4|ax1/i.test(f.model)) return 16;
  return 8;
}

const nominalPower = (f: Fixture): number | undefined => {
  const powers = f.modes.map((m) => m.powerW).filter((w): w is number => w !== undefined);
  return powers.length ? Math.max(...powers) : undefined;
};

/**
 * Expand a fixture's mode list with the standard personality family for its
 * colour engine, keeping any hand-authored modes (they lead the list) and
 * de-duplicating by name.
 */
export function enrichModes(f: Fixture): FixtureMode[] {
  const engine = detectEngine(f);
  const power = nominalPower(f);
  const generated = [...staticModes(engine, power), ...pixelModes(engine, detectMaxPixels(f), power)];

  const seen = new Set<string>();
  const out: FixtureMode[] = [];
  for (const m of [...f.modes, ...generated]) {
    const key = m.name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(m);
  }
  return out;
}
