import type {
  DmxValue,
  FixtureId,
  PatchItemId,
  UniverseNumber,
} from './common';

/**
 * The patch is the list of physical fixture instances on a job, with their
 * universe + address. It is produced by the showfile macro's address-packing
 * pass, can be pulled from / pushed to a console, and feeds the cheat sheet,
 * stops calc and power budget.
 */

export interface PatchItem {
  id: PatchItemId;
  fixtureId: FixtureId;
  mode: string;
  /** Display label, e.g. "Key 1", "Backlight SR". */
  label: string;
  universe: UniverseNumber;
  startAddress: number; // 1..512
  footprint: number; // channels consumed in this mode
  /** Optional link back to a tagged position on the Polycam plot. */
  plotTagId?: string;
  /** Physical position note for on-set addressing. */
  positionNote?: string;
  /** Last intensity seen from the console, if any (0..255). Not persisted live. */
  liveIntensity?: DmxValue;
}

/**
 * Per-job universe preference. Maps each universe to a transport (wireless vs
 * copper DMX) and the fixture types the user wants packed there. The macro
 * honours this when assigning addresses.
 */
export interface UniverseProfile {
  name: string;
  universes: UniverseAssignment[];
}

export type UniverseTransport = 'wireless' | 'copper';

export interface UniverseAssignment {
  universe: UniverseNumber;
  transport: UniverseTransport;
  /** Fixture types preferred in this universe. Empty = any. */
  preferredFixtureIds: FixtureId[];
  /** Optional human note, e.g. "Wireless rig — movers only". */
  note?: string;
}

/** Result of the packing pass: either a clean patch or overflow diagnostics. */
export interface PackResult {
  items: PatchItem[];
  overflows: UniverseOverflow[];
  /** Address clashes detected when merging with an existing patch. */
  clashes: AddressClash[];
}

export interface UniverseOverflow {
  universe: UniverseNumber;
  /** Channels requested beyond 512. */
  excessChannels: number;
}

export interface AddressClash {
  universe: UniverseNumber;
  startAddress: number;
  existingItemId: PatchItemId;
  incomingLabel: string;
}
