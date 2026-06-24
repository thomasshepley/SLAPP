import { useMemo, useState } from 'react';
import { Field, NumberInput, Result, Select, TextInput, ToolCard, ToolPage } from '@/components/ui';
import {
  applyMiredShift,
  classifyTint,
  kelvinToMired,
  miredToKelvin,
  percentToCct,
  rgbToHsi,
  suggestCtGel,
} from '@/services/calc';
import { useGels } from '@/hooks/useLibrary';
import type { Gel } from '@/models/colour';

export function ColourTools() {
  return (
    <ToolPage section={7} title="Colour Tools" intro="Gels, colour temperature and tint — all offline.">
      <MiredConverter />
      <CtCorrection />
      <GelToRgb />
      <PercentToCct />
      <DuvTint />
      <GelSearch />
    </ToolPage>
  );
}

function MiredConverter() {
  const [k, setK] = useState<number | ''>(5600);
  const mired = typeof k === 'number' && k > 0 ? Math.round(kelvinToMired(k)) : '—';
  const [m, setM] = useState<number | ''>(179);
  const kFromM = typeof m === 'number' && m > 0 ? Math.round(miredToKelvin(m)) : '—';
  return (
    <ToolCard title="Colour temperature ↔ Mired">
      <Field label="Colour temperature">
        <NumberInput value={k} onChange={setK} suffix="K" />
      </Field>
      <Result label="Mired" value={mired} unit="MK⁻¹" />
      <Field label="Mired">
        <NumberInput value={m} onChange={setM} suffix="MK⁻¹" />
      </Field>
      <Result label="Colour temperature" value={kFromM} unit="K" />
    </ToolCard>
  );
}

function CtCorrection() {
  const [src, setSrc] = useState<number | ''>(5600);
  const [tgt, setTgt] = useState<number | ''>(3200);
  const suggestion = useMemo(() => {
    if (typeof src !== 'number' || typeof tgt !== 'number' || src <= 0 || tgt <= 0) return null;
    return suggestCtGel(src, tgt);
  }, [src, tgt]);
  return (
    <ToolCard title="CTO / CTB calculator">
      <Field label="Source CCT">
        <NumberInput value={src} onChange={setSrc} suffix="K" />
      </Field>
      <Field label="Target CCT">
        <NumberInput value={tgt} onChange={setTgt} suffix="K" />
      </Field>
      {suggestion && (
        <>
          <Result
            label="Suggested gel"
            value={suggestion.family === 'none' ? 'No correction needed' : `${suggestion.strength} ${suggestion.family}`}
            emphasis
          />
          <Result label="Gel mired shift" value={suggestion.gelMiredShift} unit="MK⁻¹" />
          <Result label="Residual error" value={suggestion.residualMired} unit="MK⁻¹" />
          {typeof src === 'number' && (
            <Result
              label="Resulting CCT with gel"
              value={Math.round(applyMiredShift(src, suggestion.gelMiredShift))}
              unit="K"
            />
          )}
        </>
      )}
    </ToolCard>
  );
}

function GelToRgb() {
  const [r, setR] = useState<number | ''>(245);
  const [g, setG] = useState<number | ''>(180);
  const [b, setB] = useState<number | ''>(110);
  const rgb = { r: num(r), g: num(g), b: num(b) };
  const hsi = rgbToHsi(rgb);
  return (
    <ToolCard title="Gel → RGB / HSI">
      <div className="row3">
        <Field label="R"><NumberInput value={r} onChange={setR} min={0} max={255} /></Field>
        <Field label="G"><NumberInput value={g} onChange={setG} min={0} max={255} /></Field>
        <Field label="B"><NumberInput value={b} onChange={setB} min={0} max={255} /></Field>
      </div>
      <div className="swatch" style={{ background: `rgb(${rgb.r},${rgb.g},${rgb.b})` }} />
      <Result label="Hue" value={hsi.h} unit="°" />
      <Result label="Saturation" value={`${Math.round(hsi.s * 100)}%`} />
      <Result label="Intensity" value={`${Math.round(hsi.i * 100)}%`} />
    </ToolCard>
  );
}

function PercentToCct() {
  const [pct, setPct] = useState<number | ''>(50);
  const [min, setMin] = useState<number | ''>(2700);
  const [max, setMax] = useState<number | ''>(6500);
  const cct =
    typeof pct === 'number' && typeof min === 'number' && typeof max === 'number'
      ? percentToCct(pct, min, max)
      : '—';
  return (
    <ToolCard title="Percentage → CCT (tunable white)">
      <Field label="Fader position" hint="0–100%">
        <NumberInput value={pct} onChange={setPct} min={0} max={100} suffix="%" />
      </Field>
      <div className="row2">
        <Field label="Min CCT"><NumberInput value={min} onChange={setMin} suffix="K" /></Field>
        <Field label="Max CCT"><NumberInput value={max} onChange={setMax} suffix="K" /></Field>
      </div>
      <Result label="Output CCT" value={cct} unit="K" emphasis />
    </ToolCard>
  );
}

function DuvTint() {
  const [duv, setDuv] = useState<number | ''>(0.002);
  const reading = typeof duv === 'number' ? classifyTint(duv) : null;
  return (
    <ToolCard title="Duv / tint">
      <Field label="Duv" hint="+ green / − magenta">
        <NumberInput value={duv} onChange={setDuv} step={0.0005} />
      </Field>
      {reading && (
        <>
          <Result
            label="Tint"
            value={reading.direction === 'neutral' ? 'Neutral' : `${reading.direction}`}
            emphasis
            warn={reading.direction !== 'neutral'}
          />
          <Result label="≈ CC correction" value={`${reading.ccEighths}/8`} />
        </>
      )}
    </ToolCard>
  );
}

function GelSearch() {
  const [q, setQ] = useState('');
  const [mfr, setMfr] = useState<'all' | Gel['manufacturer']>('all');
  const gels = useGels(q, mfr);
  return (
    <ToolCard title="Gel search">
      <Field label="Search">
        <TextInput value={q} onChange={setQ} placeholder="name, number, colour…" />
      </Field>
      <Field label="Manufacturer">
        <Select
          value={mfr}
          onChange={setMfr}
          options={[
            { value: 'all', label: 'All' },
            { value: 'Lee', label: 'Lee' },
            { value: 'Rosco', label: 'Rosco' },
            { value: 'GAM', label: 'GAM' },
          ]}
        />
      </Field>
      <ul className="gel-list">
        {gels.map((gel) => (
          <li key={gel.id} className="gel-row">
            <span
              className="gel-swatch"
              style={{
                background: gel.swatchRgb
                  ? `rgb(${gel.swatchRgb.r},${gel.swatchRgb.g},${gel.swatchRgb.b})`
                  : '#444',
              }}
            />
            <span className="gel-meta">
              <strong>{gel.manufacturer} {gel.number}</strong>
              <span className="muted">{gel.name}</span>
            </span>
            {gel.miredShift !== undefined && (
              <span className="gel-mired muted">{gel.miredShift > 0 ? '+' : ''}{gel.miredShift} MK⁻¹</span>
            )}
          </li>
        ))}
        {gels.length === 0 && <li className="muted">No gels match.</li>}
      </ul>
    </ToolCard>
  );
}

const num = (v: number | ''): number => (typeof v === 'number' ? v : 0);
