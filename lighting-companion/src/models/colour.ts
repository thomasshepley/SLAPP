import type { Auditable, GelId, Kelvin } from './common';

/**
 * Gel reference library for the colour tools. Bundled as seed data (Rosco /
 * Lee / GAM swatch books) and stored locally. Transmission curves are optional
 * because not every gel has published spectral data.
 */

export type GelManufacturer = 'Rosco' | 'Lee' | 'GAM' | 'Other';

export interface Gel extends Auditable {
  id: GelId;
  manufacturer: GelManufacturer;
  /** Swatch number, e.g. "201", "L201". */
  number: string;
  name: string; // "Full C.T. Blue"
  description?: string;
  /** sRGB approximation of the gel over a reference white, for swatches. */
  swatchRgb?: Rgb;
  /** Spectral transmission, 0..1 per wavelength bin, where published. */
  transmission?: TransmissionCurve;
  /** For CT correction gels: nominal mired shift. Negative = warming (CTO). */
  miredShift?: number;
}

export interface Rgb {
  r: number; // 0..255
  g: number;
  b: number;
}

export interface Hsi {
  h: number; // 0..360
  s: number; // 0..1
  i: number; // 0..1
}

export interface TransmissionCurve {
  /** Wavelength of the first sample, nm. */
  startNm: number;
  /** Spacing between samples, nm (commonly 5). */
  stepNm: number;
  /** Transmission 0..1, one per bin from startNm upward. */
  values: number[];
}

/** A point in CCT/Duv space, used by the Duv/tint display. */
export interface ChromaticityPoint {
  cct: Kelvin;
  /** Distance from the Planckian locus; +green / -magenta. */
  duv: number;
}
