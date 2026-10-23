import type { DmxValue, FixtureId, UniverseNumber } from './common';

/**
 * Console connection config + the shapes exchanged with MA3 / Titan over their
 * HTTP APIs. The two consoles speak different protocols; the
 * `services/console` adapters normalise to these neutral types so the rest of
 * the app never branches on console make.
 */

export type ConsoleType = 'ma3' | 'titan';

export interface ConsoleConfig {
  type: ConsoleType;
  /** IPv4 of the console / Titan PC on the lighting WAP. */
  host: string;
  /** Defaults differ per console; adapter fills in if omitted. */
  port?: number;
  /** Optional auth (Titan session, MA3 user/pin) — never synced off-device. */
  credentials?: ConsoleCredentials;
}

export interface ConsoleCredentials {
  user?: string;
  password?: string;
}

export type ConnectionState =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'reconnecting'
  | 'error';

export interface ConnectionStatus {
  state: ConnectionState;
  lastConnectedAt?: string;
  /** Round-trip latency of the last successful poll, ms. */
  latencyMs?: number;
  message?: string;
}

// --- Neutral patch & level snapshots --------------------------------------
// What we pull FROM a console. Addresses are absolute (universe + address).

export interface ConsolePatchEntry {
  /** Console-side fixture id (MA3 FID / Titan handle), for write-back. */
  consoleFixtureId: string;
  label?: string;
  /** Matched library fixture, if we recognised the type. May be unresolved. */
  fixtureId?: FixtureId;
  /** Raw fixture-type name reported by the console, for matching/diagnostics. */
  reportedType: string;
  mode?: string;
  universe: UniverseNumber;
  startAddress: number;
  footprint: number;
}

export interface ConsoleLevel {
  consoleFixtureId: string;
  /** Current intensity as an 8-bit DMX value, 0..255. */
  intensity: DmxValue;
}

/** A push payload built by the showfile macro and handed to an adapter. */
export interface PatchPushItem {
  fixtureId: FixtureId;
  reportedType: string;
  mode: string;
  label: string;
  universe: UniverseNumber;
  startAddress: number;
  footprint: number;
}
