import type { ChannelAttribute } from '@/models/fixture';

/**
 * Maps GDTF attribute names (from the standard Attribute Definitions) to our
 * canonical ChannelAttribute roles. GDTF uses a large, structured vocabulary;
 * we only distinguish the roles the app reasons about and bucket the rest into
 * 'other'. Matching is case-insensitive and prefix-aware (e.g. "Gobo1",
 * "Gobo2WheelSpin" both map to gobo).
 *
 * Reference: GDTF standard attribute names (gdtf-share.com / DIN SPEC 15800).
 */

const EXACT: Record<string, ChannelAttribute> = {
  dimmer: 'intensity',
  // Additive colour mixing
  coloradd_r: 'red',
  coloradd_g: 'green',
  coloradd_b: 'blue',
  coloradd_w: 'white',
  coloradd_ww: 'white',
  coloradd_cw: 'white',
  coloradd_a: 'amber',
  coloradd_uv: 'other',
  coloradd_l: 'lime',
  coloradd_c: 'cyan',
  coloradd_m: 'magenta',
  coloradd_y: 'yellow',
  colorrgb_red: 'red',
  colorrgb_green: 'green',
  colorrgb_blue: 'blue',
  colorrgb_white: 'white',
  colorrgb_amber: 'amber',
  colorrgb_cyan: 'cyan',
  colorrgb_magenta: 'magenta',
  colorrgb_yellow: 'yellow',
  // Subtractive CMY
  colorsub_c: 'cyan',
  colorsub_m: 'magenta',
  colorsub_y: 'yellow',
  // White point / CCT
  colortemperature: 'cct',
  cto: 'cct',
  ctb: 'cct',
  ctc: 'cct',
  colortemperaturecorrection: 'cct',
  whitepoint: 'cct',
  // Green/magenta tint
  tint: 'tint',
  greenmagenta: 'tint',
  plusgreen: 'tint',
  // Movement
  pan: 'pan',
  tilt: 'tilt',
  // Optics
  zoom: 'zoom',
  focus: 'focus',
  // Function/control
  function: 'control',
  control: 'control',
  fixtureglobalreset: 'control',
  fixtureglobalsettings: 'control',
};

/** Prefix rules applied (in order) when no exact match is found. */
const PREFIX: Array<[string, ChannelAttribute]> = [
  ['gobo', 'gobo'],
  ['color', 'colourWheel'], // ColorWheel, Color1, Color2…  (after exact rgb/cct above)
  ['cto', 'cct'],
  ['ctb', 'cct'],
  ['shutter', 'shutter'],
  ['strobe', 'shutter'],
  ['pan', 'pan'],
  ['tilt', 'tilt'],
  ['zoom', 'zoom'],
  ['focus', 'focus'],
  ['iris', 'other'],
  ['frost', 'other'],
  ['prism', 'other'],
  ['dimmer', 'intensity'],
];

export function mapGdtfAttribute(gdtfName: string | undefined): ChannelAttribute {
  if (!gdtfName) return 'other';
  const key = gdtfName.trim().toLowerCase();
  const exact = EXACT[key];
  if (exact) return exact;
  for (const [prefix, attr] of PREFIX) {
    if (key.startsWith(prefix)) return attr;
  }
  return 'other';
}
