import { useMemo, useState } from 'react';
import { Field, NumberInput, Result, ToolCard, ToolPage } from '@/components/ui';
import { FixturePicker } from '@/components/FixturePicker';
import { beamDiameterAt, distanceForLux, luxAtDistance, throwForDiameter } from '@/services/calc';
import { useFixtures } from '@/hooks/useLibrary';
import { DEFAULT_PHOTOMETRY_KEY, type Fixture } from '@/models/fixture';
import type { FixtureId } from '@/models/common';

export function BeamTools() {
  return (
    <ToolPage section={9} title="Beam & Photometry" intro="Inverse square law and beam coverage calculators.">
      <InverseSquare />
      <BeamCoverage />
    </ToolPage>
  );
}

function InverseSquare() {
  const fixtures = useFixtures();
  const [fixtureId, setFixtureId] = useState<FixtureId | ''>('');
  const [isManual, setIsManual] = useState(false);
  const [lux1m, setLux1m] = useState<number | ''>(10000);
  const [distance, setDistance] = useState<number | ''>(3);
  const [targetLux, setTargetLux] = useState<number | ''>(500);

  const selectedLux = useMemo(() => {
    if (isManual) return typeof lux1m === 'number' ? lux1m : null;
    const fx = fixtures.find((f) => f.id === fixtureId);
    const p = fx?.photometry[DEFAULT_PHOTOMETRY_KEY];
    return p?.luxAt1m ?? null;
  }, [fixtureId, isManual, lux1m, fixtures]);

  const atDistance =
    selectedLux !== null && typeof distance === 'number' && distance > 0
      ? luxAtDistance(selectedLux, distance)
      : null;
  const reqDistance =
    selectedLux !== null && typeof targetLux === 'number' && targetLux > 0
      ? distanceForLux(selectedLux, targetLux)
      : null;

  return (
    <ToolCard title="Inverse square law">
      <Field label="Fixture">
        <FixturePicker
          value={isManual ? 'manual' as FixtureId : fixtureId}
          onChange={(id) => {
            if (id === 'manual') {
              setIsManual(true);
              setFixtureId('');
            } else {
              setIsManual(false);
              setFixtureId(id);
            }
          }}
          filter={(f: Fixture) => !!(f.photometry[DEFAULT_PHOTOMETRY_KEY]?.luxAt1m)}
          showManualOption
        />
      </Field>
      {isManual ? (
        <Field label="Output at 1 m"><NumberInput value={lux1m} onChange={setLux1m} suffix="lux" /></Field>
      ) : fixtureId ? (
        <Result label="Output at 1 m" value={selectedLux ?? '—'} unit="lux" />
      ) : null}
      <Field label="Throw distance"><NumberInput value={distance} onChange={setDistance} suffix="m" /></Field>
      <Result label="Illuminance at distance" value={atDistance !== null ? Math.round(atDistance) : '—'} unit="lux" emphasis />
      <hr className="divider" />
      <Field label="Reverse: target illuminance"><NumberInput value={targetLux} onChange={setTargetLux} suffix="lux" /></Field>
      <Result label="Required distance" value={reqDistance !== null ? reqDistance.toFixed(2) : '—'} unit="m" />
    </ToolCard>
  );
}

function BeamCoverage() {
  const fixtures = useFixtures();
  const [fixtureId, setFixtureId] = useState<FixtureId | ''>('');
  const [isManual, setIsManual] = useState(false);
  const [angle, setAngle] = useState<number | ''>(30);
  const [distance, setDistance] = useState<number | ''>(4);
  const [targetDia, setTargetDia] = useState<number | ''>(3);

  const zoomFixture = fixtures.find((f) => f.id === fixtureId && f.beam.zoomRangeDeg);
  const effectiveAngle = isManual
    ? (typeof angle === 'number' ? angle : null)
    : (() => {
      const fx = fixtures.find((f) => f.id === fixtureId);
      return fx?.beam.angleDeg ?? fx?.beam.zoomRangeDeg?.minDeg ?? null;
    })();

  const diameter =
    effectiveAngle !== null && typeof distance === 'number'
      ? beamDiameterAt(effectiveAngle, distance)
      : null;
  const reqThrow =
    effectiveAngle !== null && typeof targetDia === 'number'
      ? throwForDiameter(effectiveAngle, targetDia)
      : null;

  return (
    <ToolCard title="Beam coverage">
      <Field label="Fixture">
        <FixturePicker
          value={isManual ? 'manual' as FixtureId : fixtureId}
          onChange={(id) => {
            if (id === 'manual') {
              setIsManual(true);
              setFixtureId('');
            } else {
              setIsManual(false);
              setFixtureId(id);
            }
          }}
          filter={(f: Fixture) => !!(f.beam.angleDeg || f.beam.zoomRangeDeg)}
          showManualOption
        />
      </Field>
      {isManual ? (
        <Field label="Beam angle"><NumberInput value={angle} onChange={setAngle} suffix="°" /></Field>
      ) : fixtureId ? (
        <Result label="Beam angle" value={effectiveAngle ?? '—'} unit="°" />
      ) : null}
      <Field label="Throw distance"><NumberInput value={distance} onChange={setDistance} suffix="m" /></Field>
      <Result label="Beam diameter" value={diameter !== null ? diameter.toFixed(2) : '—'} unit="m" emphasis />
      {zoomFixture?.beam.zoomRangeDeg && typeof distance === 'number' && (
        <Result
          label="Across zoom range"
          value={`${beamDiameterAt(zoomFixture.beam.zoomRangeDeg.minDeg, distance).toFixed(1)}–${beamDiameterAt(zoomFixture.beam.zoomRangeDeg.maxDeg, distance).toFixed(1)} m`}
        />
      )}
      <hr className="divider" />
      <Field label="Reverse: target diameter"><NumberInput value={targetDia} onChange={setTargetDia} suffix="m" /></Field>
      <Result label="Required throw" value={reqThrow !== null ? reqThrow.toFixed(2) : '—'} unit="m" />
    </ToolCard>
  );
}
