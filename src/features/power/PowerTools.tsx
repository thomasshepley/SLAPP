import { useMemo, useState } from 'react';
import { Field, NumberInput, Result, Select, ToolCard, ToolPage } from '@/components/ui';
import { computePowerBudget } from '@/services/calc';
import { CABLE_RATINGS, deratedCapacity, recommendCable } from '@/services/calc';
import { useFixtures } from '@/hooks/useLibrary';
import type { PowerBudgetItem } from '@/models/power';
import type { FixtureId } from '@/models/common';

export function PowerTools() {
  return (
    <ToolPage section={10} title="Power Tools" intro="Budget the rig and size the cable.">
      <PowerBudgetCalc />
      <CableDerating />
    </ToolPage>
  );
}

function PowerBudgetCalc() {
  const fixtures = useFixtures();
  const [items, setItems] = useState<PowerBudgetItem[]>([]);
  const [voltage, setVoltage] = useState<number | ''>(230);
  const [distro, setDistro] = useState<number | ''>(32);
  const [picker, setPicker] = useState('');
  const [qty, setQty] = useState<number | ''>(1);

  const result = useMemo(
    () =>
      computePowerBudget({
        voltage: typeof voltage === 'number' ? voltage : 230,
        distroRatingA: typeof distro === 'number' ? distro : undefined,
        items,
      }),
    [items, voltage, distro],
  );

  const addItem = () => {
    const fx = fixtures.find((f) => f.id === picker);
    if (!fx) return;
    const mode = fx.modes[0];
    setItems([
      ...items,
      {
        fixtureId: fx.id,
        mode: mode?.name ?? '',
        quantity: typeof qty === 'number' ? qty : 1,
        perUnitW: mode?.powerW ?? 0,
      },
    ]);
  };

  const nameOf = (id: FixtureId) => {
    const fx = fixtures.find((f) => f.id === id);
    return fx ? `${fx.manufacturer} ${fx.model}` : id;
  };

  return (
    <ToolCard title="Power budget">
      <div className="row2">
        <Field label="Supply voltage"><NumberInput value={voltage} onChange={setVoltage} suffix="V" /></Field>
        <Field label="Distro rating"><NumberInput value={distro} onChange={setDistro} suffix="A" /></Field>
      </div>
      <Field label="Add fixture">
        <Select
          value={picker}
          onChange={setPicker}
          options={[
            { value: '', label: 'Select…' },
            ...fixtures.map((f) => ({ value: f.id, label: `${f.manufacturer} ${f.model}` })),
          ]}
        />
      </Field>
      <div className="row2">
        <Field label="Quantity"><NumberInput value={qty} onChange={setQty} min={1} /></Field>
        <button className="btn" onClick={addItem} disabled={!picker}>Add</button>
      </div>
      {items.length > 0 && (
        <ul className="line-list">
          {items.map((it, i) => (
            <li key={i} className="line-row">
              <span>{it.quantity} × {nameOf(it.fixtureId)}</span>
              <span className="muted">{it.perUnitW * it.quantity} W</span>
              <button className="chip" onClick={() => setItems(items.filter((_, j) => j !== i))}>×</button>
            </li>
          ))}
        </ul>
      )}
      <Result label="Total power" value={result.totalW} unit="W" />
      <Result label="Total current" value={result.totalA} unit="A" emphasis warn={result.overDistro} />
      {result.overDistro && <Result label="Over distro by" value={result.excessA} unit="A" warn />}
    </ToolCard>
  );
}

function CableDerating() {
  const [csa, setCsa] = useState<number>(2.5);
  const [ambient, setAmbient] = useState<number | ''>(30);
  const [load, setLoad] = useState<number | ''>(20);
  const ambientC = typeof ambient === 'number' ? ambient : 30;
  const capacity = deratedCapacity(csa, ambientC);
  const rec = typeof load === 'number' ? recommendCable(load, ambientC) : undefined;
  return (
    <ToolCard title="Cable derating reference">
      <Field label="Cable size">
        <Select
          value={String(csa)}
          onChange={(v) => setCsa(Number(v))}
          options={CABLE_RATINGS.map((r) => ({ value: String(r.csaMm2), label: `${r.csaMm2} mm²` }))}
        />
      </Field>
      <Field label="Ambient temperature"><NumberInput value={ambient} onChange={setAmbient} suffix="°C" /></Field>
      <Result label="Derated capacity" value={capacity} unit="A" emphasis />
      <hr className="divider" />
      <Field label="Recommend for load"><NumberInput value={load} onChange={setLoad} suffix="A" /></Field>
      <Result
        label="Smallest suitable cable"
        value={rec ? `${rec.csaMm2} mm²` : 'Above 25 mm²'}
        unit={rec ? `(${deratedCapacity(rec.csaMm2, ambientC)} A)` : undefined}
      />
    </ToolCard>
  );
}
