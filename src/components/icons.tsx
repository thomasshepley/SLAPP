import type { ReactNode } from 'react';

/**
 * A small hand-drawn stroke icon set (24px grid, currentColor) for navigation
 * and feature cards. Inline SVG keeps the app fully offline and themeable.
 */

const paths: Record<string, ReactNode> = {
  home: <path d="M3 11l9-7 9 7M5 10v10h5v-6h4v6h5V10" />,
  shows: (
    <>
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <path d="M3 9h18M8 5V3M16 5V3" />
    </>
  ),
  fixtures: (
    <>
      <rect x="5" y="4" width="10" height="9" rx="2" />
      <path d="M15 6.5l5-2v8l-5-2M10 13v4M6 20h8" />
    </>
  ),
  showfile: (
    <>
      <path d="M6 3h9l4 4v14H6z" />
      <path d="M14 3v5h5M9 12h7M9 16h7" />
    </>
  ),
  plot: (
    <>
      <path d="M3 6l6-3 6 3 6-3v15l-6 3-6-3-6 3z" />
      <path d="M9 3v15M15 6v15" />
    </>
  ),
  stops: (
    <>
      <circle cx="12" cy="12" r="8" />
      <path d="M12 4v16M4.5 9.5h15M4.5 14.5h15" />
    </>
  ),
  beam: (
    <>
      <path d="M4 9h4v6H4z" />
      <path d="M8 10l12-5v14L8 14" />
    </>
  ),
  power: <path d="M13 2L4 14h7l-1 8 9-12h-7z" />,
  colour: (
    <>
      <circle cx="9" cy="10" r="5" />
      <circle cx="15" cy="10" r="5" />
      <circle cx="12" cy="15" r="5" />
    </>
  ),
  camera: (
    <>
      <rect x="3" y="7" width="13" height="11" rx="2" />
      <path d="M16 11l5-3v9l-5-3" />
      <circle cx="9.5" cy="12.5" r="2.5" />
    </>
  ),
  reference: (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1" />
    </>
  ),
  console: (
    <>
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <path d="M7 15V9M12 15v-4M17 15v-6" />
    </>
  ),
  settings: (
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1" />
    </>
  ),
  search: (
    <>
      <circle cx="11" cy="11" r="6" />
      <path d="M20 20l-4.5-4.5" />
    </>
  ),
  download: <path d="M12 4v11M7 10l5 5 5-5M5 20h14" />,
  copy: (
    <>
      <rect x="8" y="8" width="12" height="12" rx="2" />
      <path d="M16 8V5a1 1 0 00-1-1H5a1 1 0 00-1 1v10a1 1 0 001 1h3" />
    </>
  ),
  back: <path d="M15 5l-7 7 7 7" />,
  upload: <path d="M12 20V9M7 14l5-5 5 5M5 4h14" />,
  check: <path d="M5 12l5 5 9-10" />,
};

export type IconName = keyof typeof paths;

export function Icon({ name, size = 20, className }: { name: IconName | string; size?: number; className?: string }) {
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.7}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name] ?? paths.home}
    </svg>
  );
}
