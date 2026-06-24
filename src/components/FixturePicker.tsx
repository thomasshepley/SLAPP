import { useMemo, useState } from 'react';
import { useFixtures } from '@/hooks/useLibrary';
import type { Fixture } from '@/models/fixture';
import type { FixtureId } from '@/models/common';

interface FixturePickerProps {
  value: FixtureId | '';
  onChange: (id: FixtureId | '', fixture: Fixture | null) => void;
  filter?: (f: Fixture) => boolean;
  showManualOption?: boolean;
}

export function FixturePicker({ value, onChange, filter, showManualOption }: FixturePickerProps) {
  const allFixtures = useFixtures();
  const fixtures = filter ? allFixtures.filter(filter) : allFixtures;

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
  const brandFixtures = grouped.find(([b]) => b === currentBrand)?.[1] ?? [];

  const selected = fixtures.find((f) => f.id === value);

  return (
    <div className="fixture-picker">
      {selected && value && (
        <div className="fp-selected">
          <span className="fp-selected-name">
            {selected.manufacturer} {selected.model}
          </span>
          <button
            className="chip"
            onClick={() => onChange('' as FixtureId, null)}
          >
            ×
          </button>
        </div>
      )}

      {!value && (
        <>
          {showManualOption && (
            <button
              className="fp-manual-btn chip"
              onClick={() => onChange('manual' as FixtureId, null)}
            >
              Manual entry
            </button>
          )}
          <div className="fp-tabs">
            {brands.map((brand) => (
              <button
                key={brand}
                className={`fp-tab${brand === currentBrand ? ' fp-tab-active' : ''}`}
                onClick={() => setActiveBrand(brand)}
              >
                {brand}
                <span className="fp-tab-count">
                  {grouped.find(([b]) => b === brand)?.[1].length}
                </span>
              </button>
            ))}
          </div>
          <ul className="fp-list">
            {brandFixtures.map((f) => (
              <li key={f.id}>
                <button
                  className="fp-item"
                  onClick={() => {
                    onChange(f.id, f);
                    setActiveBrand(null);
                  }}
                >
                  <span className="fp-item-name">{f.model}</span>
                  <span className="fp-item-meta">
                    {f.category && <span>{f.category}</span>}
                    {f.modes.length > 1 && <span>{f.modes.length} modes</span>}
                    {f.modes[0]?.powerW && <span>{f.modes[0].powerW}W</span>}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}
