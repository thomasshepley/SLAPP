import type {
  ConnectionStatus,
  ConsoleConfig,
  ConsoleLevel,
  ConsolePatchEntry,
  PatchPushItem,
} from '@/models/console';
import { ConsoleUnavailableError, type ConsoleAdapter } from './consoleAdapter';

const TITAN_DEFAULT_PORT = 4430;

/**
 * Avolites Titan Remote HTTP API adapter (Titan Mobile / onPC).
 *
 * STUB: see {@link Ma3Adapter} — same staged approach. The Titan API differs
 * from MA3 (different auth, handles, and patch representation); normalising
 * those differences to the shared types is this adapter's whole job.
 */
export class TitanAdapter implements ConsoleAdapter {
  readonly config: ConsoleConfig;
  private _status: ConnectionStatus = { state: 'disconnected' };

  constructor(config: ConsoleConfig) {
    this.config = { port: TITAN_DEFAULT_PORT, ...config };
  }

  status(): ConnectionStatus {
    return this._status;
  }

  async connect(): Promise<ConnectionStatus> {
    throw new ConsoleUnavailableError('Titan adapter not yet implemented');
  }

  async disconnect(): Promise<void> {
    this._status = { state: 'disconnected' };
  }

  async pullPatch(): Promise<ConsolePatchEntry[]> {
    throw new ConsoleUnavailableError('Titan adapter not yet implemented');
  }

  async pullLevels(): Promise<ConsoleLevel[]> {
    throw new ConsoleUnavailableError('Titan adapter not yet implemented');
  }

  async pushPatch(_items: PatchPushItem[]): Promise<void> {
    throw new ConsoleUnavailableError('Titan adapter not yet implemented');
  }
}
