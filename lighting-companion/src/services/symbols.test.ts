import { describe, expect, it } from 'vitest';
import { seedFixtures } from '@/data/fixtures';
import { symbolKindFor, symbolSvg, symbolFilename } from './symbols';

const fixtures = seedFixtures();
const kindOf = (frag: string) => {
  const f = fixtures.find((x) => `${x.manufacturer} ${x.model}`.toLowerCase().includes(frag.toLowerCase()));
  expect(f, frag).toBeDefined();
  return symbolKindFor(f!);
};

describe('plot symbols', () => {
  it('maps representative fixtures to the right symbol family', () => {
    expect(kindOf('Titan Tube')).toBe('tube');
    expect(kindOf('SkyPanel S60')).toBe('panel');
    expect(kindOf('ARRI T12')).toBe('fresnel');
    expect(kindOf('LS 600d Pro')).toBe('cob');
    expect(kindOf('Source Four 750')).toBe('profile');
    expect(kindOf('AX9 PowerPAR')).toBe('par');
    expect(kindOf('MAC Aura')).toBe('movinghead');
    expect(kindOf('NYX')).toBe('bulb');
  });

  it('gives every seed fixture a symbol', () => {
    for (const f of fixtures) expect(symbolSvg(symbolKindFor(f))).toMatch(/^<svg[\s\S]*<\/svg>$/);
  });

  it('escapes labels so user text cannot inject markup', () => {
    const svg = symbolSvg('fresnel', { label: '<script>alert(1)</script> & "Key"' });
    expect(svg).not.toContain('<script>');
    expect(svg).toContain('&lt;script&gt;');
    expect(svg).toContain('&amp;');
  });

  it('builds safe, readable filenames', () => {
    expect(symbolFilename({ manufacturer: 'DMG Lumière', model: 'SL1 Mix+' }, 'png')).toBe('dmg-lumi-re-sl1-mix.png');
  });
});
