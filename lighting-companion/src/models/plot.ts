import type { Degrees, FixtureId, PlotTagId } from './common';
import type { FileRef } from './files';

/**
 * Polycam plot import. The PDF is rendered in-app and the user taps to place
 * tags; parsing is visual, not structural, so positions are manual. Tag
 * coordinates are stored normalised (0..1) against the page box so they stay
 * correct across zoom / DPI / re-render.
 */

export interface PolycamPlot {
  pdf: FileRef;
  pageCount: number;
  tags: PlotTag[];
}

export interface PlotTag {
  id: PlotTagId;
  /** Page the tag sits on, 0-based. */
  page: number;
  /** Normalised position within the page, 0..1 from top-left. */
  x: number;
  y: number;
  fixtureId?: FixtureId;
  label: string;
  positionNote?: string;
  /** Optional aim/orientation captured on the plot. */
  rotationDeg?: Degrees;
}
