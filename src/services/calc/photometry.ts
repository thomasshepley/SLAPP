import type { Degrees, Lux, Metres } from '@/models/common';

/**
 * Beam & throw geometry. All pure, all metric in/out.
 */

/** Inverse square law: illuminance at a new distance from a 1 m reference. */
export function luxAtDistance(luxAt1m: Lux, distanceM: Metres): Lux {
  if (distanceM <= 0) return Infinity;
  return luxAt1m / (distanceM * distanceM);
}

/** Reverse ISL: distance at which a 1 m reference falls to a target lux. */
export function distanceForLux(luxAt1m: Lux, targetLux: Lux): Metres {
  if (targetLux <= 0) return Infinity;
  return Math.sqrt(luxAt1m / targetLux);
}

/** Beam diameter at a throw distance for a given full beam angle. */
export function beamDiameterAt(beamAngleDeg: Degrees, distanceM: Metres): Metres {
  const half = (beamAngleDeg / 2) * (Math.PI / 180);
  return 2 * distanceM * Math.tan(half);
}

/** Throw distance needed to cover a target diameter at a given beam angle. */
export function throwForDiameter(beamAngleDeg: Degrees, diameterM: Metres): Metres {
  const half = (beamAngleDeg / 2) * (Math.PI / 180);
  const t = Math.tan(half);
  return t === 0 ? Infinity : diameterM / (2 * t);
}
