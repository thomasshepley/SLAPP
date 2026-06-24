import type { ShowId } from './common';

/**
 * App-wide settings and GDTF sync preferences. Single-row table (id = 'app').
 * Sync runs at home over the internet; nothing here is needed on set.
 */

export const APP_SETTINGS_ID = 'app' as const;

export interface AppSettings {
  id: typeof APP_SETTINGS_ID;
  /** Brands the user wants pulled from GDTF-Share on next sync. */
  gdtfSyncBrands: string[];
  lastGdtfSyncAt?: string;
  /** Show to reopen on launch. */
  activeShowId?: ShowId;
  /** Default mains frequency for the flicker calculator. */
  mainsFrequencyHz: 50 | 60;
  /** Default supply voltage for power tools. */
  supplyVoltage: number;
  /** Distance/illuminance display units (storage is always metric/lux). */
  units: 'metric' | 'imperial';
  /** Prompt to auto-save before switching/closing shows. */
  autoSavePrompt: boolean;
}

export const DEFAULT_APP_SETTINGS: AppSettings = {
  id: APP_SETTINGS_ID,
  gdtfSyncBrands: [],
  mainsFrequencyHz: 50,
  supplyVoltage: 230,
  units: 'metric',
  autoSavePrompt: true,
};
