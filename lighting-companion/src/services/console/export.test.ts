import { describe, expect, it } from 'vitest';
import type { Fixture } from '@/models/fixture';
import type { FixtureId, PatchItemId } from '@/models/common';
import type { PatchItem } from '@/models/patch';
import { buildExportRows, fidRanges, toCsv, toMa3Macro, typeBlocks } from './export';

const fx = (id: string, model: string) =>
  [id as FixtureId, { id, manufacturer: 'ARRI', model } as unknown as Fixture] as const;
const fixtures = new Map([fx('a', 'SkyPanel S60-C'), fx('b', 'Orbiter')]);
const item = (fixtureId: string, label: string, universe: number, startAddress: number, footprint = 10): PatchItem => ({
  id: label as PatchItemId,
  fixtureId: fixtureId as FixtureId,
  mode: 'Standard',
  label,
  universe,
  startAddress,
  footprint,
});

const patch = [item('b', 'Back 1', 2, 1), item('a', 'Key 1', 1, 11), item('a', 'Key 2', 1, 1)];

describe('console export', () => {
  const rows = buildExportRows(patch, fixtures, 101);

  it('orders by universe then address and numbers FIDs sequentially', () => {
    expect(rows.map((r) => [r.fid, r.label])).toEqual([
      [101, 'Key 2'],
      [102, 'Key 1'],
      [103, 'Back 1'],
    ]);
    expect(rows[2]!.absolute).toBe(513);
  });

  it('writes MA3 Patch Fixture lines in universe.address notation', () => {
    const macro = toMa3Macro(rows, 'Test');
    expect(macro).toContain('Patch Fixture 101 1.1');
    expect(macro).toContain('Patch Fixture 102 1.11');
    expect(macro).toContain('Patch Fixture 103 2.1');
  });

  it('produces a CSV with a header and one row per fixture, escaping safely', () => {
    const csv = toCsv([{ ...rows[0]!, label: '=cmd,"x"' }]);
    const [header, line] = csv.trim().split('\r\n');
    expect(header!.startsWith('FID,Label')).toBe(true);
    expect(line).toContain(`"'=cmd,""x"""`);
  });

  it('groups by type and compacts FID ranges', () => {
    const blocks = typeBlocks(rows);
    expect(blocks).toHaveLength(2);
    expect(fidRanges([101, 102, 103, 107, 109, 110])).toBe('101 Thru 103 + 107 + 109 Thru 110');
  });
});
