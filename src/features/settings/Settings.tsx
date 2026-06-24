import { useCallback, useEffect, useState } from 'react';
import { Field, NumberInput, Result, Select, ToolCard, ToolPage } from '@/components/ui';
import { settingsRepo } from '@/db';
import { type AppSettings, DEFAULT_APP_SETTINGS } from '@/models/settings';

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

  useEffect(() => {
    settingsRepo.get().then(setSettings);
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
        <Field label="Display units">
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

      <ToolCard title="About">
        <Result label="App" value="Shepley Lighting Companion" />
        <Result label="Storage" value="IndexedDB (offline-first)" />
        <Result label="Fixture import" value="GDTF / manual entry" />
      </ToolCard>

      {saved && (
        <p className="status-line" style={{ textAlign: 'center' }}>Saved</p>
      )}
    </ToolPage>
  );
}
