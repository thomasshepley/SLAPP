import type {
  Auditable,
  Degrees,
  DmxResolution,
  DmxValue,
  FixtureId,
  Kelvin,
  Kilograms,
  Lux,
  Versioned,
  Watts,
} from './common';
import type { FileRef } from './files';

/**
 * Fixture library entry. This is GLOBAL — shared across all shows — not copied
 * per job. A show's patch references fixtures by id. Entries are seeded from a
 * curated list and from GDTF-Share sync, and are user-expandable/editable.
 */
export interface Fixture extends Auditable, Versioned {
  id: FixtureId;
  manufacturer: string;
  model: string;
  /** e.g. "LED Fresnel", "Profile", "Wash", "PAR", "Softlight". */
  category?: string;

  modes: FixtureMode[];
  /** Photometry is keyed by mode name where it differs per mode. */
  photometry: PhotometryByMode;

  colour: ColourQuality;
  /** Beam angle(s). Fixed fixtures have one; zooms have a min/max range. */
  beam: BeamSpec;
  weightKg?: Kilograms;

  manualPdf?: FileRef;
  dmxTablePdf?: FileRef;

  /** Provenance: how this entry got into the library. */
  source: FixtureSource;
  /** True for entries the user has hand-edited away from their GDTF source. */
  userModified: boolean;
}

export interface FixtureSource {
  origin: 'curated' | 'gdtf-share' | 'manual';
  /** GDTF fixture type GUID, when known — the key used for sync matching. */
  gdtfFixtureTypeId?: string;
  /** Stored .gdtf archive this entry was parsed from. */
  gdtfFile?: FileRef;
  /** GDTF-Share revision id, for detecting newer revisions on sync. */
  gdtfRevision?: string;
  lastSyncedAt?: string;
}

// --- Modes & channels -----------------------------------------------------

export interface FixtureMode {
  name: string; // e.g. "Standard 16-bit", "CMY Extended"
  /** Total DMX footprint of the mode. */
  channelCount: number;
  channels: ChannelFunction[];
  /** Power draw in this mode — modes can differ (e.g. with/without fan boost). */
  powerW?: Watts;
}

export interface ChannelFunction {
  /** 0-based offset from the fixture's start address. */
  offset: number;
  resolution: DmxResolution;
  /** Canonical role, used by the app to find e.g. the intensity channel. */
  attribute: ChannelAttribute;
  /** Human label from the GDTF / manual, e.g. "Dimmer Fine". */
  label: string;
  /** Optional value ranges (gobos, colour wheel slots, macros). */
  ranges?: ChannelRange[];
}

export interface ChannelRange {
  from: DmxValue;
  to: DmxValue;
  label: string;
}

/** Canonical attribute roles we care about programmatically. */
export type ChannelAttribute =
  | 'intensity'
  | 'red'
  | 'green'
  | 'blue'
  | 'white'
  | 'amber'
  | 'lime'
  | 'cyan'
  | 'magenta'
  | 'yellow'
  | 'cct'
  | 'tint'
  | 'pan'
  | 'tilt'
  | 'zoom'
  | 'focus'
  | 'gobo'
  | 'colourWheel'
  | 'shutter'
  | 'control'
  | 'other';

// --- Photometry & dimming -------------------------------------------------

export type PhotometryByMode = Record<string, Photometry>;
/** Conventional key for fixtures whose photometry is mode-independent. */
export const DEFAULT_PHOTOMETRY_KEY = '*';

export interface Photometry {
  /** Centre-beam illuminance at 1 metre, at full intensity. Drives ISL + stops. */
  luxAt1m?: Lux;
  /** Shape of the intensity → output relationship, used by the stops calc. */
  dimmingCurve: DimmingCurve;
}

export type DimmingCurveType = 'linear' | 'square' | 'scurve' | 'log' | 'measured';

/**
 * Either a named analytic curve, or measured sample points. `measured` lets us
 * store the real lux-at-DMX-step data the brief calls for; the others are
 * cheap closed-form approximations applied to luxAt1m.
 */
export interface DimmingCurve {
  type: DimmingCurveType;
  /**
   * Required when type === 'measured'. Monotonic samples of relative output
   * (0..1) at DMX fractions (0..1). Interpolated linearly between points.
   */
  samples?: DimmingSample[];
}

export interface DimmingSample {
  /** DMX level as a fraction of full, 0..1. */
  dmxFraction: number;
  /** Light output as a fraction of full output, 0..1. */
  outputFraction: number;
}

// --- Colour quality -------------------------------------------------------

export interface ColourQuality {
  cri?: number; // Ra, 0..100
  tlci?: number; // 0..100
  /** Fixed-CCT fixtures: nominal CCT. Variable: omit and use cctRange. */
  nativeCct?: Kelvin;
  /** Tunable-white fixtures. */
  cctRange?: { minK: Kelvin; maxK: Kelvin };
  /** True for RGBW/RGBACL etc. — enables the gel→RGB tooling. */
  hasColourMixing?: boolean;
}

// --- Beam -----------------------------------------------------------------

export interface BeamSpec {
  /** Fixed beam angle (full width to half peak). */
  angleDeg?: Degrees;
  /** Zoom fixtures: continuous range. */
  zoomRangeDeg?: { minDeg: Degrees; maxDeg: Degrees };
  /** Field angle, where published separately from beam angle. */
  fieldAngleDeg?: Degrees;
}
