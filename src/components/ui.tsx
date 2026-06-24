import type { ReactNode } from 'react';

/**
 * Small set of shared UI primitives for the tool screens. Touch-friendly for
 * iPad: large hit areas, numeric inputmode where it helps. Deliberately plain —
 * the tools are the product, not the chrome.
 */

export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <label className="field">
      <span className="field-label">{label}</span>
      {children}
      {hint && <span className="field-hint">{hint}</span>}
    </label>
  );
}

export function NumberInput({
  value,
  onChange,
  step,
  min,
  max,
  placeholder,
  suffix,
}: {
  value: number | '';
  onChange: (v: number | '') => void;
  step?: number;
  min?: number;
  max?: number;
  placeholder?: string;
  suffix?: string;
}) {
  return (
    <span className="input-wrap">
      <input
        type="number"
        inputMode="decimal"
        className="input"
        value={value}
        step={step}
        min={min}
        max={max}
        placeholder={placeholder}
        onChange={(e) => {
          const raw = e.target.value;
          onChange(raw === '' ? '' : Number(raw));
        }}
      />
      {suffix && <span className="input-suffix">{suffix}</span>}
    </span>
  );
}

export function Select<T extends string>({
  value,
  onChange,
  options,
}: {
  value: T;
  onChange: (v: T) => void;
  options: Array<{ value: T; label: string }>;
}) {
  return (
    <select className="input" value={value} onChange={(e) => onChange(e.target.value as T)}>
      {options.map((o) => (
        <option key={o.value} value={o.value}>
          {o.label}
        </option>
      ))}
    </select>
  );
}

export function TextInput({
  value,
  onChange,
  placeholder,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <input
      type="text"
      className="input"
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
    />
  );
}

export function Result({
  label,
  value,
  unit,
  emphasis,
  warn,
}: {
  label: string;
  value: ReactNode;
  unit?: string;
  emphasis?: boolean;
  warn?: boolean;
}) {
  return (
    <div className={`result${emphasis ? ' result-emphasis' : ''}${warn ? ' result-warn' : ''}`}>
      <span className="result-label">{label}</span>
      <span className="result-value">
        {value}
        {unit && <span className="result-unit"> {unit}</span>}
      </span>
    </div>
  );
}

export function ToolCard({ title, children }: { title?: string; children: ReactNode }) {
  return (
    <section className="tool-card">
      {title && <h2 className="tool-card-title">{title}</h2>}
      {children}
    </section>
  );
}

export function ToolPage({
  section: _section,
  title,
  intro,
  children,
}: {
  section?: number;
  title: string;
  intro?: string;
  children: ReactNode;
}) {
  return (
    <section className="page">
      <h1>{title}</h1>
      {intro && <p className="muted">{intro}</p>}
      <div className="tool-stack">{children}</div>
    </section>
  );
}
