import type { PatchItem } from '@/models/patch';
import type { AddressClash } from '@/models/patch';
import type { CrossShowImportSelection } from '@/models/show';
import type { Show } from '@/models/show';

/**
 * Pure merge logic for the cross-show import tool (brief §2). Given the current
 * show, a source show and a selection, produce the resulting patch plus any
 * address clashes detected. Kept side-effect-free so it's unit-testable and the
 * UI can preview conflicts before committing.
 */

export interface CrossImportResult {
  patch: PatchItem[];
  clashes: AddressClash[];
}

/** Two patch items clash if they overlap in the same universe. */
function overlaps(a: PatchItem, b: PatchItem): boolean {
  if (a.universe !== b.universe) return false;
  const aEnd = a.startAddress + a.footprint - 1;
  const bEnd = b.startAddress + b.footprint - 1;
  return a.startAddress <= bEnd && b.startAddress <= aEnd;
}

export function applyCrossImport(
  current: Show,
  source: Show,
  selection: CrossShowImportSelection,
): CrossImportResult {
  // Which source patch items are being brought in.
  let incoming: PatchItem[] = [];
  if (selection.importPatch === 'all') {
    incoming = source.patch;
  } else if (selection.importPatch !== 'none') {
    const wanted = new Set(selection.importPatch.fixtureIds);
    incoming = source.patch.filter((p) => wanted.has(p.fixtureId));
  }

  if (selection.conflictStrategy === 'replace') {
    // Replace wholesale — no clashes possible against an empty base.
    return { patch: [...incoming], clashes: [] };
  }

  // Merge: keep current, append incoming, flag overlaps against current.
  const clashes: AddressClash[] = [];
  const merged = [...current.patch];
  for (const item of incoming) {
    const hit = current.patch.find((existing) => overlaps(existing, item));
    if (hit) {
      clashes.push({
        universe: item.universe,
        startAddress: item.startAddress,
        existingItemId: hit.id,
        incomingLabel: item.label,
      });
      // Conflicting item is reported but not merged, leaving the user to resolve.
      continue;
    }
    merged.push(item);
  }
  return { patch: merged, clashes };
}
