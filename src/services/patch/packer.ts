import { newId, type FixtureId, type PatchItemId } from '@/models/common';
import type { Fixture } from '@/models/fixture';
import type {
  PackResult,
  PatchItem,
  UniverseAssignment,
  UniverseProfile,
} from '@/models/patch';

const UNIVERSE_SIZE = 512;

/** A request line for the macro: N of a fixture type, in a given mode. */
export interface PackRequest {
  fixtureId: FixtureId;
  mode: string;
  quantity: number;
  /** Base label; instances get a numeric suffix ("Key 1", "Key 2"). */
  labelPrefix: string;
}

/**
 * Address-packing pass for the new-showfile macro. Packs fixtures sequentially
 * into universes, honouring the per-job universe profile (a fixture type prefers
 * the universes it is assigned to; otherwise it falls into any universe with
 * room), and flags overflow past 512 channels. Pure and deterministic so the
 * result is reproducible and testable.
 */
export function packPatch(
  requests: PackRequest[],
  profile: UniverseProfile,
  fixtures: Map<FixtureId, Fixture>,
): PackResult {
  const items: PatchItem[] = [];
  const overflowChannels = new Map<number, number>();
  // Next free 1-based address per universe.
  const nextAddress = new Map<number, number>();
  for (const u of profile.universes) nextAddress.set(u.universe, 1);

  for (const req of requests) {
    const fixture = fixtures.get(req.fixtureId);
    if (!fixture) continue;
    const mode = fixture.modes.find((m) => m.name === req.mode);
    if (!mode) continue;
    const footprint = mode.channelCount;

    for (let i = 0; i < req.quantity; i++) {
      const universe = pickUniverse(req.fixtureId, footprint, profile, nextAddress);
      if (universe === undefined) {
        overflowChannels.set(
          0,
          (overflowChannels.get(0) ?? 0) + footprint,
        );
        continue;
      }
      const startAddress = nextAddress.get(universe)!;
      items.push({
        id: newId<PatchItemId>(),
        fixtureId: req.fixtureId,
        mode: req.mode,
        label: `${req.labelPrefix} ${i + 1}`,
        universe,
        startAddress,
        footprint,
      });
      nextAddress.set(universe, startAddress + footprint);
    }
  }

  const overflows = [...overflowChannels.entries()]
    .filter(([, excess]) => excess > 0)
    .map(([universe, excessChannels]) => ({ universe, excessChannels }));

  return { items, overflows, clashes: [] };
}

/**
 * Choose a universe for one fixture instance: prefer universes that list this
 * fixture type and still have room, then any universe with room, in profile
 * order. Returns undefined when nothing fits (overflow).
 */
function pickUniverse(
  fixtureId: FixtureId,
  footprint: number,
  profile: UniverseProfile,
  nextAddress: Map<number, number>,
): number | undefined {
  const fits = (u: UniverseAssignment): boolean =>
    nextAddress.get(u.universe)! + footprint - 1 <= UNIVERSE_SIZE;

  const preferred = profile.universes.filter(
    (u) => u.preferredFixtureIds.includes(fixtureId) && fits(u),
  );
  if (preferred[0]) return preferred[0].universe;

  const anyRoom = profile.universes.filter(
    (u) => u.preferredFixtureIds.length === 0 && fits(u),
  );
  if (anyRoom[0]) return anyRoom[0].universe;

  // Last resort: any universe at all with room.
  const fallback = profile.universes.find(fits);
  return fallback?.universe;
}
