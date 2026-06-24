import { useEffect, useMemo, useRef, useState } from 'react';
import { Field, NumberInput, Result, Select, ToolCard, ToolPage } from '@/components/ui';
import { useSettings } from '@/hooks/useSettings';
import {
  apertureForExposure,
  checkFlicker,
  luxToEv100,
  ndDensityToStops,
  stackNd,
  stopsToNdDensity,
} from '@/services/calc';

const FRAME_RATE_PRESETS = [24, 25, 30, 48, 50, 60, 96, 120, 240];

export function CameraTools() {
  return (
    <ToolPage section={8} title="Camera & Exposure" intro="Exposure, flicker and ND — for working with the DoP.">
      <ExposureCalc />
      <FlickerCalc />
      <NdStack />
    </ToolPage>
  );
}

function ExposureCalc() {
  const [lux, setLux] = useState<number | ''>(2500);
  const [iso, setIso] = useState<number | ''>(800);
  const [shutter, setShutter] = useState<number | ''>(50);
  const ev100 = typeof lux === 'number' && lux > 0 ? luxToEv100(lux) : null;
  const aperture = useMemo(() => {
    if (typeof lux !== 'number' || typeof iso !== 'number' || typeof shutter !== 'number') return null;
    if (lux <= 0 || iso <= 0 || shutter <= 0) return null;
    return apertureForExposure(lux, iso, shutter);
  }, [lux, iso, shutter]);
  return (
    <ToolCard title="Exposure calculator">
      <Field label="Incident reading">
        <NumberInput value={lux} onChange={setLux} suffix="lux" />
      </Field>
      <div className="row2">
        <Field label="ISO"><NumberInput value={iso} onChange={setIso} /></Field>
        <Field label="Shutter" hint="1/x s"><NumberInput value={shutter} onChange={setShutter} /></Field>
      </div>
      {ev100 !== null && <Result label="EV (ISO 100)" value={ev100.toFixed(1)} />}
      {aperture && (
        <Result label="Aperture" value={`f/${aperture.nearestStop}`} unit={`(exact f/${aperture.exact})`} emphasis />
      )}
    </ToolCard>
  );
}

function FlickerCalc() {
  const settings = useSettings();
  const [fps, setFps] = useState<number>(24);
  const [mains, setMains] = useState<'50' | '60'>(String(settings.mainsFrequencyHz) as '50' | '60');
  const [shutter, setShutter] = useState<number | ''>(48);

  // Default the mains frequency from settings until the user changes it here.
  const mainsEdited = useRef(false);
  useEffect(() => {
    if (!mainsEdited.current) setMains(String(settings.mainsFrequencyHz) as '50' | '60');
  }, [settings.mainsFrequencyHz]);
  const mainsHz = mains === '50' ? 50 : 60;
  const check = typeof shutter === 'number' && shutter > 0 ? checkFlicker(shutter, mainsHz) : null;
  return (
    <ToolCard title="Flicker-free shutter">
      <div className="row2">
        <Field label="Frame rate">
          <Select
            value={String(fps)}
            onChange={(v) => setFps(Number(v))}
            options={FRAME_RATE_PRESETS.map((f) => ({ value: String(f), label: `${f} fps` }))}
          />
        </Field>
        <Field label="Mains frequency">
          <Select
            value={mains}
            onChange={(v) => { mainsEdited.current = true; setMains(v); }}
            options={[
              { value: '50', label: '50 Hz' },
              { value: '60', label: '60 Hz' },
            ]}
          />
        </Field>
      </div>
      <Field label="Shutter speed" hint="1/x s">
        <NumberInput value={shutter} onChange={setShutter} />
      </Field>
      {check && (
        <>
          <Result
            label="Flicker-safe?"
            value={check.safe ? 'Safe' : 'Risk of flicker'}
            emphasis
            warn={!check.safe}
          />
          <Result label="Mains flicker" value={check.flickerHz} unit="Hz" />
          <Result label="Nearest safe shutters" value={check.nearestSafe.map((s) => `1/${s}`).join(', ')} />
          <p className="field-hint">Frame rate {fps} fps — keep shutter a whole multiple of {check.flickerHz} Hz.</p>
        </>
      )}
    </ToolCard>
  );
}

function NdStack() {
  const [densities, setDensities] = useState<number[]>([0.3, 0.6]);
  const [targetStops, setTargetStops] = useState<number | ''>(3);
  const stack = stackNd(densities);
  const neededDensity = typeof targetStops === 'number' ? stopsToNdDensity(targetStops) : 0;
  return (
    <ToolCard title="ND filter stack">
      <Field label="Filters (optical density)">
        <div className="chip-row">
          {densities.map((d, i) => (
            <button key={i} className="chip" onClick={() => setDensities(densities.filter((_, j) => j !== i))}>
              {d.toFixed(1)} ×
            </button>
          ))}
        </div>
      </Field>
      <div className="chip-row">
        {[0.3, 0.6, 0.9, 1.2].map((d) => (
          <button key={d} className="chip chip-add" onClick={() => setDensities([...densities, d])}>
            + {d.toFixed(1)}
          </button>
        ))}
      </div>
      <Result label="Total ND" value={stack.totalDensity.toFixed(1)} unit="density" />
      <Result label="Stops lost" value={stack.totalStops.toFixed(1)} unit="stops" emphasis />
      <hr className="divider" />
      <Field label="Reverse: stops to lose">
        <NumberInput value={targetStops} onChange={setTargetStops} suffix="stops" />
      </Field>
      <Result label="Required ND density" value={neededDensity.toFixed(2)} />
      <Result
        label="≈ ND value"
        value={`ND${Math.round(Math.pow(2, ndDensityToStops(neededDensity)))}`}
      />
    </ToolCard>
  );
}
