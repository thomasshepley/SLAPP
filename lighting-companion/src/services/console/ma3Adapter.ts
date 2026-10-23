import type {
  ConnectionStatus,
  ConsoleConfig,
  ConsoleLevel,
  ConsolePatchEntry,
  PatchPushItem,
} from '@/models/console';
import { ConsoleUnavailableError, type ConsoleAdapter } from './consoleAdapter';

const MA3_DEFAULT_PORT = 80;

/**
 * grandMA3 HTTP API adapter.
 *
 * STUB: transport wiring is intentionally not implemented yet — the data model
 * and the normalised {@link ConsoleAdapter} contract come first (see the
 * brief's closing note). Each method throws so the UI cleanly falls back to
 * read-only mode until the endpoints are filled in. The mapping work each
 * method owns is documented inline so the implementation is unambiguous.
 */
export class Ma3Adapter implements ConsoleAdapter {
  readonly config: ConsoleConfig;
  private _status: ConnectionStatus = { state: 'disconnected' };

  constructor(config: ConsoleConfig) {
    this.config = { port: MA3_DEFAULT_PORT, ...config };
  }

  status(): ConnectionStatus {
    return this._status;
  }

  async connect(): Promise<ConnectionStatus> {
    // TODO: open session against MA3 HTTP API, set connected + latency.
    throw new ConsoleUnavailableError('MA3 adapter not yet implemented');
  }

  async disconnect(): Promise<void> {
    this._status = { state: 'disconnected' };
  }

  async pullPatch(): Promise<ConsolePatchEntry[]> {
    // TODO: GET patch, map MA3 FixtureType/Mode → ConsolePatchEntry,
    // resolve fixtureId via fixtureRepo.byGdtfTypeId.
    throw new ConsoleUnavailableError('MA3 adapter not yet implemented');
  }

  async pullLevels(): Promise<ConsoleLevel[]> {
    // TODO: GET programmer/output values, normalise to 0..255.
    throw new ConsoleUnavailableError('MA3 adapter not yet implemented');
  }

  async pushPatch(_items: PatchPushItem[]): Promise<void> {
    // TODO: build + POST an MA3 import macro / showfile fragment.
    throw new ConsoleUnavailableError('MA3 adapter not yet implemented');
  }
}
