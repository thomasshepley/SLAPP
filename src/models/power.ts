import type { Amps, FixtureId, Volts, Watts } from './common';

/**
 * Power budget for a job. Can be built by hand or seeded from the patch /
 * console fixture list. Current is computed from total watts at the chosen
 * supply voltage; the brief defaults to 230 V single phase.
 */

export interface PowerBudget {
  /** Supply voltage used for the W → A conversion. */
  voltage: Volts; // default 230
  /** Distro / circuit rating to flag against. */
  distroRatingA?: Amps;
  items: PowerBudgetItem[];
}

export interface PowerBudgetItem {
  fixtureId: FixtureId;
  mode: string;
  quantity: number;
  /** Snapshot of per-unit draw at add-time (library power can change later). */
  perUnitW: Watts;
}

export interface PowerBudgetResult {
  totalW: Watts;
  totalA: Amps;
  overDistro: boolean;
  /** Amps over the rating, when overDistro. */
  excessA?: Amps;
}
