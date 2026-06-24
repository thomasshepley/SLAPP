import { now, type GelId } from '@/models/common';
import type { Gel } from '@/models/colour';

/**
 * Seed gel data — a starter set of the most-reached-for swatches across Lee and
 * Rosco. Mired shifts are nominal manufacturer figures (CT correction); swatch
 * RGB is an sRGB approximation for the UI only. User-expandable like the brief
 * asks; this is just what's in the box on day one.
 */

type GelSeed = Omit<Gel, 'id' | 'createdAt' | 'updatedAt'>;

const SEED: GelSeed[] = [
  // --- Colour temperature correction ---
  { manufacturer: 'Lee', number: '201', name: 'Full C.T. Blue', description: 'Converts tungsten 3200K to daylight 5700K', miredShift: -131, swatchRgb: { r: 150, g: 190, b: 235 } },
  { manufacturer: 'Lee', number: '202', name: 'Half C.T. Blue', miredShift: -68, swatchRgb: { r: 180, g: 205, b: 235 } },
  { manufacturer: 'Lee', number: '203', name: 'Quarter C.T. Blue', miredShift: -35, swatchRgb: { r: 205, g: 220, b: 238 } },
  { manufacturer: 'Lee', number: '204', name: 'Full C.T. Orange', description: 'Converts daylight 5700K to tungsten 3200K', miredShift: 167, swatchRgb: { r: 245, g: 180, b: 110 } },
  { manufacturer: 'Lee', number: '205', name: 'Half C.T. Orange', miredShift: 81, swatchRgb: { r: 248, g: 205, b: 150 } },
  { manufacturer: 'Lee', number: '206', name: 'Quarter C.T. Orange', miredShift: 42, swatchRgb: { r: 250, g: 222, b: 185 } },
  { manufacturer: 'Rosco', number: 'R3202', name: 'Full Blue (CTB)', miredShift: -131, swatchRgb: { r: 150, g: 190, b: 235 } },
  { manufacturer: 'Rosco', number: 'R3407', name: 'Full CTO', miredShift: 167, swatchRgb: { r: 245, g: 180, b: 110 } },

  // --- Plus/minus green (camera matching) ---
  { manufacturer: 'Lee', number: '244', name: 'Plus Green (Fluorescent 5700K)', description: 'Adds green to match fluorescents', swatchRgb: { r: 200, g: 230, b: 160 } },
  { manufacturer: 'Lee', number: '247', name: 'Minus Green (Fluorescent 3600K)', description: 'Removes green / adds magenta', swatchRgb: { r: 225, g: 175, b: 215 } },

  // --- Diffusion ---
  { manufacturer: 'Lee', number: '216', name: 'White Diffusion', description: 'Full diffusion, ~1.6 stop loss', swatchRgb: { r: 240, g: 240, b: 240 } },
  { manufacturer: 'Lee', number: '250', name: 'Half White Diffusion', swatchRgb: { r: 245, g: 245, b: 245 } },
  { manufacturer: 'Lee', number: '251', name: 'Quarter White Diffusion', swatchRgb: { r: 248, g: 248, b: 248 } },

  // --- Colour ---
  { manufacturer: 'Lee', number: '106', name: 'Primary Red', swatchRgb: { r: 220, g: 20, b: 30 } },
  { manufacturer: 'Lee', number: '101', name: 'Yellow', swatchRgb: { r: 245, g: 220, b: 30 } },
  { manufacturer: 'Lee', number: '124', name: 'Dark Green', swatchRgb: { r: 20, g: 120, b: 60 } },
  { manufacturer: 'Lee', number: '120', name: 'Deep Blue', swatchRgb: { r: 20, g: 50, b: 160 } },
  { manufacturer: 'Lee', number: '128', name: 'Bright Pink', swatchRgb: { r: 225, g: 40, b: 130 } },
  { manufacturer: 'Lee', number: '147', name: 'Apricot', description: 'Warm skin-friendly amber', swatchRgb: { r: 245, g: 175, b: 120 } },
  { manufacturer: 'Rosco', number: 'R26', name: 'Light Red', swatchRgb: { r: 225, g: 60, b: 60 } },
  { manufacturer: 'GAM', number: '720', name: 'Caribbean Blue', swatchRgb: { r: 30, g: 150, b: 200 } },
];

export function seedGels(): Gel[] {
  const stamp = now();
  return SEED.map((g, i) => ({
    ...g,
    // Deterministic ids so re-seeding is idempotent (see db/seed.ts).
    id: `gel-${g.manufacturer}-${g.number}-${i}` as GelId,
    createdAt: stamp,
    updatedAt: stamp,
  }));
}
