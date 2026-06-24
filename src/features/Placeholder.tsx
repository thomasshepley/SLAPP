import { useParams } from 'react-router-dom';
import { FEATURES } from './manifest';

/**
 * Shared scaffold page. Every feature route renders this until its real module
 * is built, so the structure is navigable and the data/service layers below it
 * can be wired one screen at a time.
 */
export function Placeholder() {
  const { featureId } = useParams();
  const feature = FEATURES.find((f) => f.id === featureId);

  if (!feature) {
    return (
      <section className="page">
        <h1>Not found</h1>
        <p>No feature matches “{featureId}”.</p>
      </section>
    );
  }

  return (
    <section className="page">
      <p className="eyebrow">Section {feature.section}</p>
      <h1>{feature.title}</h1>
      <p>{feature.summary}</p>
      <p className="muted">
        UI not built yet — the data model, storage layer and calculation engines
        for this area are in place under <code>src/models</code>,{' '}
        <code>src/db</code> and <code>src/services</code>.
      </p>
    </section>
  );
}
