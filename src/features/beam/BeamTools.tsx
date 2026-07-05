import { useMemo, useState } from 'react';
import { Field, NumberInput, Result, ToolCard, ToolPage } from '@/components/ui';
import { FixturePicker } from '@/components/FixturePicker';
import { beamDiameterAt, distanceForLux, luxAtDistance, throwForDiameter } from '@/services/calc';
import { useFixtures } from '@/hooks/useLibrary';
import { useUnits, useMeasure } from '@/hooks/useUnits';
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
  const u = useUnits();
  const [fixtureId, setFixtureId] = useState<FixtureId | ''>('');
  const [isManual, setIsManual] = useState(false);
  const [lux1m, setLux1m, lux1mCanonical] = useMeasure(10000, u.lux);
  const [distance, setDistance, distanceM] = useMeasure(3, u.dist);
  const [targetLux, setTargetLux, targetLuxCanonical] = useMeasure(500, u.lux);

  const selectedLux = useMemo(() => {
    if (isManual) return typeof lux1mCanonical === 'number' ? lux1mCanonical : null;
    const fx = fixtures.find((f) => f.id === fixtureId);
    const p = fx?.photometry[DEFAULT_PHOTOMETRY_KEY];
    return p?.luxAt1m ?? null;
  }, [fixtureId, isManual, lux1mCanonical, fixtures]);

  const atDistance =
    selectedLux !== null && typeof distanceM === 'number' && distanceM > 0
      ? luxAtDistance(selectedLux, distanceM)
      : null;
  const reqDistance =
    selectedLux !== null && typeof targetLuxCanonical === 'number' && targetLuxCanonical > 0
      ? distanceForLux(selectedLux, targetLuxCanonical)
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
        <Field label="Output at 1 m"><NumberInput value={lux1m} onChange={setLux1m} suffix={u.lux.unit} /></Field>
      ) : fixtureId ? (
        <Result label="Output at 1 m" value={selectedLux !== null ? u.lux.format(selectedLux) : '—'} unit={u.lux.unit} />
      ) : null}
      <Field label="Throw distance"><NumberInput value={distance} onChange={setDistance} suffix={u.dist.unit} /></Field>
      <Result label="Illuminance at distance" value={atDistance !== null ? u.lux.format(atDistance) : '—'} unit={u.lux.unit} emphasis />
      <hr className="divider" />
      <Field label="Reverse: target illuminance"><NumberInput value={targetLux} onChange={setTargetLux} suffix={u.lux.unit} /></Field>
      <Result label="Required distance" value={reqDistance !== null ? u.dist.format(reqDistance) : '—'} unit={u.dist.unit} />
    </ToolCard>
  );
}

function BeamCoverage() {
  const fixtures = useFixtures();
  const u = useUnits();
  const [fixtureId, setFixtureId] = useState<FixtureId | ''>('');
  const [isManual, setIsManual] = useState(false);
  const [angle, setAngle] = useState<number | ''>(30);
  const [distance, setDistance, distanceM] = useMeasure(4, u.dist);
  const [targetDia, setTargetDia, targetDiaM] = useMeasure(3, u.dist);

  const zoomFixture = fixtures.find((f) => f.id === fixtureId && f.beam.zoomRangeDeg);
  const effectiveAngle = isManual
    ? (typeof angle === 'number' ? angle : null)
    : (() => {
      const fx = fixtures.find((f) => f.id === fixtureId);
      return fx?.beam.angleDeg ?? fx?.beam.zoomRangeDeg?.minDeg ?? null;
    })();

  const diameter =
    effectiveAngle !== null && typeof distanceM === 'number'
      ? beamDiameterAt(effectiveAngle, distanceM)
      : null;
  const reqThrow =
    effectiveAngle !== null && typeof targetDiaM === 'number'
      ? throwForDiameter(effectiveAngle, targetDiaM)
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
      <Field label="Throw distance"><NumberInput value={distance} onChange={setDistance} suffix={u.dist.unit} /></Field>
      <Result label="Beam diameter" value={diameter !== null ? u.dist.format(diameter) : '—'} unit={u.dist.unit} emphasis />
      {zoomFixture?.beam.zoomRangeDeg && typeof distanceM === 'number' && (
        <Result
          label="Across zoom range"
          value={`${u.dist.format(beamDiameterAt(zoomFixture.beam.zoomRangeDeg.minDeg, distanceM))}–${u.dist.format(beamDiameterAt(zoomFixture.beam.zoomRangeDeg.maxDeg, distanceM))} ${u.dist.unit}`}
        />
      )}
      <hr className="divider" />
      <Field label="Reverse: target diameter"><NumberInput value={targetDia} onChange={setTargetDia} suffix={u.dist.unit} /></Field>
      <Result label="Required throw" value={reqThrow !== null ? u.dist.format(reqThrow) : '—'} unit={u.dist.unit} />
    </ToolCard>
  );
}
