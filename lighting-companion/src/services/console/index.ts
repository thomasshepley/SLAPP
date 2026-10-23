import type { ConsoleConfig } from '@/models/console';
import type { ConsoleAdapter } from './consoleAdapter';
import { Ma3Adapter } from './ma3Adapter';
import { TitanAdapter } from './titanAdapter';

export { ConsoleUnavailableError } from './consoleAdapter';
export type { ConsoleAdapter } from './consoleAdapter';

/** Build the right adapter for a job's console config. */
export function createConsoleAdapter(config: ConsoleConfig): ConsoleAdapter {
  switch (config.type) {
    case 'ma3':
      return new Ma3Adapter(config);
    case 'titan':
      return new TitanAdapter(config);
    default: {
      const exhaustive: never = config.type;
      throw new Error(`Unknown console type: ${String(exhaustive)}`);
    }
  }
}
