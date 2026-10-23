import { useMemo, useState } from 'react';
import { useFixtures } from '@/hooks/useLibrary';
import type { Fixture } from '@/models/fixture';
import type { FixtureId } from '@/models/common';
import { FixtureSymbol } from './FixtureSymbol';
import { Icon } from './icons';

interface FixturePickerProps {
  value: FixtureId | '';
  onChange: (id: FixtureId | '', fixture: Fixture | null) => void;
  filter?: (f: Fixture) => boolean;
  showManualOption?: boolean;
}

/** Search-first fixture chooser: type to search all brands, or browse by brand tab. */
export function FixturePicker({ value, onChange, filter, showManualOption }: FixturePickerProps) {
  const allFixtures = useFixtures();
  const fixtures = useMemo(() => (filter ? allFixtures.filter(filter) : allFixtures), [allFixtures, filter]);
  const [query, setQuery] = useState('');

  const grouped = useMemo(() => {
    const map = new Map<string, Fixture[]>();
    for (const f of fixtures) {
      const group = map.get(f.manufacturer) ?? [];
      group.push(f);
      map.set(f.manufacturer, group);
    }
    return [...map.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [fixtures]);

  const brands = useMemo(() => grouped.map(([brand]) => brand), [grouped]);
  const [activeBrand, setActiveBrand] = useState<string | null>(null);
  const currentBrand = activeBrand && brands.includes(activeBrand) ? activeBrand : brands[0] ?? null;

  const q = query.trim().toLowerCase();
  const visible = useMemo(() => {
    if (!q) return grouped.find(([b]) => b === currentBrand)?.[1] ?? [];
    const terms = q.split(/\s+/);
    return fixtures
      .filter((f) => {
        const hay = `${f.manufacturer} ${f.model} ${f.category ?? ''}`.toLowerCase();
        return terms.every((t) => hay.includes(t));
      })
      .slice(0, 40);
  }, [q, grouped, currentBrand, fixtures]);

  const isManual = value === 'manual';
  const selected = fixtures.find((f) => f.id === value);

  if (isManual || selected) {
    return (
      <div className="fp-selected">
        {selected && <FixtureSymbol fixture={selected} size={28} />}
        <span className="fp-selected-name">
          {isManual ? 'Manual entry' : (
            <>
              <span className="muted">{selected!.manufacturer}</span> {selected!.model}
            </>
          )}
        </span>
        <button className="chip" onClick={() => onChange('' as FixtureId, null)}>Change</button>
      </div>
    );
  }

  const pick = (f: Fixture) => {
    onChange(f.id, f);
    setActiveBrand(null);
    setQuery('');
  };

  return (
    <div className="fixture-picker">
      <div className="fp-search">
        <Icon name="search" size={18} />
        <input
          type="search"
          className="input"
          value={query}
          placeholder={`Search ${fixtures.length} fixtures — e.g. "titan", "skypanel 60"`}
          onChange={(e) => setQuery(e.target.value)}
        />
        {showManualOption && (
          <button className="chip" onClick={() => onChange('manual' as FixtureId, null)}>
            Manual
          </button>
        )}
      </div>

      {!q && (
        <div className="fp-tabs">
          {brands.map((brand) => (
            <button
              key={brand}
              className={`fp-tab${brand === currentBrand ? ' fp-tab-active' : ''}`}
              onClick={() => setActiveBrand(brand)}
            >
              {brand}
              <span className="fp-tab-count">{grouped.find(([b]) => b === brand)?.[1].length}</span>
            </button>
          ))}
        </div>
      )}

      <ul className="fp-list">
        {visible.map((f) => (
          <li key={f.id}>
            <button className="fp-item" onClick={() => pick(f)}>
              <FixtureSymbol fixture={f} size={26} />
              <span className="fp-item-name">
                {q && <span className="muted">{f.manufacturer} </span>}
                {f.model}
              </span>
              <span className="fp-item-meta">
                {f.category && <span>{f.category}</span>}
                {f.modes.length > 1 && <span>{f.modes.length} modes</span>}
                {maxW(f) !== undefined && <span>{maxW(f)} W</span>}
              </span>
            </button>
          </li>
        ))}
        {q && visible.length === 0 && <li className="muted fp-none">No fixtures match “{query}”.</li>}
      </ul>
    </div>
  );
}

function maxW(f: Fixture): number | undefined {
  const w = f.modes.map((m) => m.powerW).filter((x): x is number => x !== undefined);
  return w.length ? Math.max(...w) : undefined;
}
