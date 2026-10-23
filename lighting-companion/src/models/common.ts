/**
 * Shared primitives used across every domain model.
 *
 * IDs are plain strings (UUID v4 generated with `crypto.randomUUID()`), but we
 * brand them by entity so the compiler stops you handing a ShowId where a
 * FixtureId is expected. The brand is a compile-time fiction only — at runtime
 * these are ordinary strings and serialise straight to JSON / IndexedDB keys.
 */

export type Brand<T, B extends string> = T & { readonly __brand: B };

export type FixtureId = Brand<string, 'FixtureId'>;
export type ShowId = Brand<string, 'ShowId'>;
export type PatchItemId = Brand<string, 'PatchItemId'>;
export type PlotTagId = Brand<string, 'PlotTagId'>;
export type FileId = Brand<string, 'FileId'>;
export type GelId = Brand<string, 'GelId'>;

/** ISO 8601 timestamp, e.g. "2026-06-24T10:30:00.000Z". */
export type IsoTimestamp = Brand<string, 'IsoTimestamp'>;

export const newId = <T extends string>(): T => crypto.randomUUID() as T;
export const now = (): IsoTimestamp => new Date().toISOString() as IsoTimestamp;

/** Created/updated bookkeeping carried by every persisted aggregate. */
export interface Auditable {
  createdAt: IsoTimestamp;
  updatedAt: IsoTimestamp;
}

/** Schema version stamped onto each record so migrations can be targeted. */
export interface Versioned {
  /** Bumped whenever the shape of this record's domain changes. */
  schemaVersion: number;
}

// --- Physical units -------------------------------------------------------
// We keep a single canonical unit per quantity in storage (SI-ish, metric)
// and convert at the UI edge. This avoids unit ambiguity in calculations.

export type Lux = number; // illuminance
export type Watts = number; // real power
export type Amps = number; // current
export type Volts = number; // voltage
export type Kelvin = number; // correlated colour temperature
export type Mired = number; // micro reciprocal degrees (1e6 / Kelvin)
export type Kilograms = number; // mass
export type Metres = number; // distance
export type Degrees = number; // angle (beam, azimuth, elevation)

/** A DMX address: 1-based channel within a universe. */
export type DmxAddress = number; // 1..512
/** A DMX level. */
export type DmxValue = number; // 0..255 (8-bit) — see DmxResolution
export type UniverseNumber = number; // 1-based universe index

export type DmxResolution = 8 | 16 | 24;
