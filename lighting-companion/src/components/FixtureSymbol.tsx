import { useMemo } from 'react';
import type { Fixture } from '@/models/fixture';
import { symbolKindFor, symbolSvg, type SymbolKind } from '@/services/symbols';

/** Inline plot symbol for a fixture (themed via currentColor). */
export function FixtureSymbol({
  fixture,
  kind,
  size = 32,
  label,
  className,
}: {
  fixture?: Pick<Fixture, 'model' | 'category'>;
  kind?: SymbolKind;
  size?: number;
  label?: string;
  className?: string;
}) {
  const k = kind ?? (fixture ? symbolKindFor(fixture) : 'fresnel');
  // Markup is generated locally from a fixed template set (label is escaped).
  const html = useMemo(() => symbolSvg(k, { size, label }), [k, size, label]);
  return <span className={`fx-symbol ${className ?? ''}`} aria-hidden="true" dangerouslySetInnerHTML={{ __html: html }} />;
}
