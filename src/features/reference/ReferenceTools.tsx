import { useMemo, useState } from 'react';
import { Field, NumberInput, Result, Select, ToolCard, ToolPage } from '@/components/ui';
import { bpmToRpm, rpmToBpm, sunPosition, sunTimes } from '@/services/calc';
import type { TimeRange } from '@/services/calc';

export function ReferenceTools() {
  return (
    <ToolPage section={11} title="On-Set Reference" intro="Sun position and gobo sync.">
      <SunCalc />
      <GoboBpm />
    </ToolPage>
  );
}

function fmtMin(min: number | null): string {
  if (min === null) return '—';
  const wrapped = ((min % 1440) + 1440) % 1440;
  const h = Math.floor(wrapped / 60);
  const m = Math.round(wrapped % 60);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function fmtRange(r: TimeRange | null): string {
  return r ? `${fmtMin(r.startMin)} – ${fmtMin(r.endMin)}` : '—';
}

function SunCalc() {
  const today = new Date();
  const [lat, setLat] = useState<number | ''>(51.5);
  const [lon, setLon] = useState<number | ''>(-0.13);
  const [offset, setOffset] = useState<number | ''>(1);
  const [dateStr, setDateStr] = useState(today.toISOString().slice(0, 10));
  const [timeStr, setTimeStr] = useState('12:00');

  const input = useMemo(() => {
    if (typeof lat !== 'number' || typeof lon !== 'number' || typeof offset !== 'number') return null;
    const date = new Date(`${dateStr}T${timeStr}:00Z`);
    if (Number.isNaN(date.getTime())) return null;
    // Adjust the UTC instant so the entered wall-clock time is local time.
    const utcInstant = new Date(date.getTime() - offset * 3_600_000);
    return { date: utcInstant, latitude: lat, longitude: lon, utcOffsetHours: offset };
  }, [lat, lon, offset, dateStr, timeStr]);

  const times = useMemo(() => (input ? sunTimes(input) : null), [input]);
  const pos = useMemo(() => (input ? sunPosition(input) : null), [input]);

  return (
    <ToolCard title="Sun position & golden hour">
      <div className="row2">
        <Field label="Latitude" hint="+N / −S"><NumberInput value={lat} onChange={setLat} step={0.01} /></Field>
        <Field label="Longitude" hint="+E / −W"><NumberInput value={lon} onChange={setLon} step={0.01} /></Field>
      </div>
      <div className="row3">
        <Field label="UTC offset"><NumberInput value={offset} onChange={setOffset} step={0.5} suffix="h" /></Field>
        <Field label="Date">
          <input type="date" className="input" value={dateStr} onChange={(e) => setDateStr(e.target.value)} />
        </Field>
        <Field label="Time">
          <input type="time" className="input" value={timeStr} onChange={(e) => setTimeStr(e.target.value)} />
        </Field>
      </div>
      {times && (
        <>
          <Result label="Sunrise" value={fmtMin(times.sunriseMin)} />
          <Result label="Sunset" value={fmtMin(times.sunsetMin)} />
          <Result label="Solar noon" value={fmtMin(times.solarNoonMin)} />
          <Result label="Golden hour (AM)" value={fmtRange(times.goldenHourMorning)} />
          <Result label="Golden hour (PM)" value={fmtRange(times.goldenHourEvening)} emphasis />
          <Result label="Blue hour (AM)" value={fmtRange(times.blueHourMorning)} />
          <Result label="Blue hour (PM)" value={fmtRange(times.blueHourEvening)} />
        </>
      )}
      {pos && (
        <>
          <hr className="divider" />
          <Result label="Sun azimuth (at time)" value={pos.azimuth.toFixed(1)} unit="° from N" />
          <Result label="Sun elevation (at time)" value={pos.elevation.toFixed(1)} unit="°" emphasis />
        </>
      )}
    </ToolCard>
  );
}

function GoboBpm() {
  const [bpm, setBpm] = useState<number | ''>(120);
  const [rpm, setRpm] = useState<number | ''>(120);
  const [mode, setMode] = useState<'beat' | 'bar'>('beat');
  const [beatsPerBar, setBeatsPerBar] = useState<number | ''>(4);
  const bpb = typeof beatsPerBar === 'number' ? beatsPerBar : 4;
  return (
    <ToolCard title="Gobo rotation ↔ BPM">
      <div className="row2">
        <Field label="Sync">
          <Select
            value={mode}
            onChange={setMode}
            options={[
              { value: 'beat', label: 'Per beat' },
              { value: 'bar', label: 'Per bar' },
            ]}
          />
        </Field>
        {mode === 'bar' && (
          <Field label="Beats / bar"><NumberInput value={beatsPerBar} onChange={setBeatsPerBar} min={1} /></Field>
        )}
      </div>
      <Field label="Tempo"><NumberInput value={bpm} onChange={setBpm} suffix="BPM" /></Field>
      <Result label="Rotation speed" value={typeof bpm === 'number' ? bpmToRpm(bpm, mode, bpb) : '—'} unit="RPM" emphasis />
      <hr className="divider" />
      <Field label="Rotation speed"><NumberInput value={rpm} onChange={setRpm} suffix="RPM" /></Field>
      <Result label="Tempo" value={typeof rpm === 'number' ? rpmToBpm(rpm, mode, bpb) : '—'} unit="BPM" />
    </ToolCard>
  );
}
