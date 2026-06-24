import type {
  ConnectionStatus,
  ConsoleConfig,
  ConsoleLevel,
  ConsolePatchEntry,
  PatchPushItem,
} from '@/models/console';

/**
 * Common contract both console integrations implement. The app talks only to
 * this interface; MA3 vs Titan differences live entirely inside the concrete
 * adapters. Every method is async and may reject — the UI runs in read-only /
 * offline mode whenever no adapter is connected, per the brief.
 */
export interface ConsoleAdapter {
  readonly config: ConsoleConfig;

  connect(): Promise<ConnectionStatus>;
  disconnect(): Promise<void>;
  status(): ConnectionStatus;

  /** Pull the current patch (fixture type, universe, address, mode). */
  pullPatch(): Promise<ConsolePatchEntry[]>;
  /** Pull current intensity per fixture. */
  pullLevels(): Promise<ConsoleLevel[]>;
  /** Push a freshly built patch (new showfile macro). */
  pushPatch(items: PatchPushItem[]): Promise<void>;
}

/** Thrown for not-yet-connected or transport failures, so callers can degrade. */
export class ConsoleUnavailableError extends Error {
  constructor(message = 'No console connected') {
    super(message);
    this.name = 'ConsoleUnavailableError';
  }
}
