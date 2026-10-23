import type { ReactNode } from 'react';

/**
 * Small set of shared UI primitives for the tool screens. Touch-friendly for
 * iPad: large hit areas, numeric inputmode where it helps. Deliberately plain —
 * the tools are the product, not the chrome.
 */

/**
 * Labelled form row. Simple controls get a real <label> (tap the label to
 * focus the input). Compound widgets — pickers, segmented controls, button
 * groups — must pass `group`: a <label> re-dispatches clicks to its first
 * control, so a click on one button inside it would also "click" another.
 */
export function Field({
  label,
  hint,
  group,
  children,
}: {
  label: string;
  hint?: string;
  group?: boolean;
  children: ReactNode;
}) {
  const body = (
    <>
      <span className="field-label">{label}</span>
      {children}
      {hint && <span className="field-hint">{hint}</span>}
    </>
  );
  return group ? (
    <div className="field" role="group" aria-label={label}>
      {body}
    </div>
  ) : (
    <label className="field">{body}</label>
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

export function ToolCard({
  title,
  wide,
  aside,
  children,
}: {
  title?: string;
  /** Span the full width of the tool grid (tables, long lists). */
  wide?: boolean;
  /** Optional element shown at the right of the title row. */
  aside?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className={`tool-card${wide ? ' tool-card-wide' : ''}`}>
      {(title || aside) && (
        <div className="tool-card-head">
          {title && <h2 className="tool-card-title">{title}</h2>}
          {aside}
        </div>
      )}
      {children}
    </section>
  );
}

export function EmptyState({ icon, title, children }: { icon?: ReactNode; title: string; children?: ReactNode }) {
  return (
    <div className="empty">
      {icon && <span className="empty-icon">{icon}</span>}
      <strong>{title}</strong>
      {children && <span className="muted">{children}</span>}
    </div>
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
