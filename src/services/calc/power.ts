import type { PowerBudget, PowerBudgetResult } from '@/models/power';

/**
 * Power budget. Total real power summed across items, current from P = V·I at
 * the configured supply voltage (brief default 230 V), flagged against the
 * distro rating where one is set.
 */
export function computePowerBudget(budget: PowerBudget): PowerBudgetResult {
  const totalW = budget.items.reduce((sum, item) => sum + item.perUnitW * item.quantity, 0);
  const totalA = budget.voltage > 0 ? totalW / budget.voltage : 0;
  const rating = budget.distroRatingA;
  const overDistro = rating !== undefined && totalA > rating;
  return {
    totalW: round1(totalW),
    totalA: round2(totalA),
    overDistro,
    excessA: overDistro && rating !== undefined ? round2(totalA - rating) : undefined,
  };
}

const round1 = (n: number): number => Math.round(n * 10) / 10;
const round2 = (n: number): number => Math.round(n * 100) / 100;
