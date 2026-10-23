import { Link } from 'react-router-dom';
import { EmptyState } from '@/components/ui';
import { Icon } from '@/components/icons';

/** Fallback for unknown /f/:featureId routes (e.g. an old bookmark). */
export function Placeholder() {
  return (
    <section className="page">
      <h1>Page not found</h1>
      <EmptyState icon={<Icon name="search" size={30} />} title="That tool doesn’t exist (any more)">
        <Link to="/">Back to Home →</Link>
      </EmptyState>
    </section>
  );
}
