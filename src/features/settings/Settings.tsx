import { useCallback, useEffect, useState } from 'react';
import { Field, NumberInput, Result, Select, ToolCard, ToolPage } from '@/components/ui';
import { restoreCuratedLibrary, settingsRepo } from '@/db';
import { useFixtures } from '@/hooks/useLibrary';
import { type AppSettings, DEFAULT_APP_SETTINGS } from '@/models/settings';

const VERSION = typeof __APP_VERSION__ !== 'undefined' ? __APP_VERSION__ : 'dev';

const UNITS: Array<{ value: 'metric' | 'imperial'; label: string }> = [
  { value: 'metric', label: 'Metric (m, kg, lux)' },
  { value: 'imperial', label: 'Imperial (ft, lb, fc)' },
];

const MAINS: Array<{ value: '50' | '60'; label: string }> = [
  { value: '50', label: '50 Hz (UK / EU / AU)' },
  { value: '60', label: '60 Hz (US / Canada / Japan)' },
];

export function Settings() {
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_APP_SETTINGS);
  const [saved, setSaved] = useState(false);
  const [restoreStatus, setRestoreStatus] = useState<string | null>(null);
  const fixtures = useFixtures();
  const brandCount = new Set(fixtures.map((f) => f.manufacturer)).size;

  useEffect(() => {
    settingsRepo.get().then(setSettings);
  }, []);

  const handleRestore = useCallback(async () => {
    setRestoreStatus('Restoring…');
    const n = await restoreCuratedLibrary();
    setRestoreStatus(
      n === 0
        ? 'Library already up to date.'
        : `Added or refreshed ${n} curated fixture${n === 1 ? '' : 's'}.`,
    );
    setTimeout(() => setRestoreStatus(null), 5000);
  }, []);

  const update = useCallback(async (patch: Partial<Omit<AppSettings, 'id'>>) => {
    const next = await settingsRepo.update(patch);
    setSettings(next);
    setSaved(true);
    setTimeout(() => setSaved(false), 1500);
  }, []);

  return (
    <ToolPage title="Settings" intro="Defaults used across all tools.">
      <ToolCard title="Units & Region">
        <Field label="Display units" hint="Applies to distance, illuminance and weight across all tools">
          <Select
            value={settings.units}
            onChange={(v) => update({ units: v })}
            options={UNITS}
          />
        </Field>
        <Field label="Mains frequency" hint="Used by the flicker-free shutter calculator">
          <Select
            value={String(settings.mainsFrequencyHz) as '50' | '60'}
            onChange={(v) => update({ mainsFrequencyHz: Number(v) as 50 | 60 })}
            options={MAINS}
          />
        </Field>
        <Field label="Supply voltage" hint="Default for power budget calculations">
          <NumberInput
            value={settings.supplyVoltage}
            onChange={(v) => {
              if (typeof v === 'number' && v > 0) update({ supplyVoltage: v });
            }}
            min={100}
            max={480}
            suffix="V"
          />
        </Field>
      </ToolCard>

      <ToolCard title="Shows">
        <Field label="Auto-save prompt">
          <Select
            value={settings.autoSavePrompt ? 'on' : 'off'}
            onChange={(v) => update({ autoSavePrompt: v === 'on' })}
            options={[
              { value: 'on', label: 'Prompt before switching shows' },
              { value: 'off', label: 'Switch without prompting' },
            ]}
          />
        </Field>
      </ToolCard>

      <ToolCard title="Fixture Library">
        <Result label="Fixtures cached" value={fixtures.length} unit="offline" emphasis />
        <Result label="Brands" value={brandCount} />
        <p className="field-hint">
          The full curated library is bundled and cached for offline use. If an app
          update added new fixtures, restore them here.
        </p>
        <button className="btn btn-secondary" style={{ alignSelf: 'flex-start' }} onClick={handleRestore}>
          Restore fixture library
        </button>
        {restoreStatus && <p className="status-line">{restoreStatus}</p>}
      </ToolCard>

      <ToolCard title="About">
        <Result label="App" value="Shepley Lighting Companion" />
        <Result label="Version" value={`v${VERSION}`} emphasis />
        <Result label="Storage" value="IndexedDB (offline-first)" />
        <Result label="Fixture import" value="GDTF / manual entry" />
      </ToolCard>

      {saved && (
        <p className="status-line" style={{ textAlign: 'center' }}>Saved</p>
      )}
    </ToolPage>
  );
}
