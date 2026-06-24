import * as pdfjsLib from 'pdfjs-dist';
// Vite resolves this to a hashed URL for the worker bundle.
import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url';

pdfjsLib.GlobalWorkerOptions.workerSrc = workerUrl;

/**
 * Thin wrapper over pdf.js for the Polycam plot import. Rendering is canvas-only
 * and browser-only (no unit coverage), so it's isolated here behind a small
 * surface the UI can call and degrade from if a PDF won't open.
 */

export interface LoadedPdf {
  pageCount: number;
  /** Render a page into a canvas at the given CSS width; returns its size. */
  renderPage: (
    pageNumber: number,
    canvas: HTMLCanvasElement,
    cssWidth: number,
  ) => Promise<{ width: number; height: number }>;
  destroy: () => void;
}

export async function loadPdf(data: ArrayBuffer): Promise<LoadedPdf> {
  const doc = await pdfjsLib.getDocument({ data }).promise;
  return {
    pageCount: doc.numPages,
    async renderPage(pageNumber, canvas, cssWidth) {
      const page = await doc.getPage(pageNumber);
      const unscaled = page.getViewport({ scale: 1 });
      const scale = cssWidth / unscaled.width;
      const dpr = window.devicePixelRatio || 1;
      const viewport = page.getViewport({ scale: scale * dpr });
      const ctx = canvas.getContext('2d');
      if (!ctx) throw new Error('No 2D canvas context');
      canvas.width = viewport.width;
      canvas.height = viewport.height;
      canvas.style.width = `${cssWidth}px`;
      canvas.style.height = `${viewport.height / dpr}px`;
      await page.render({ canvasContext: ctx, viewport }).promise;
      return { width: cssWidth, height: viewport.height / dpr };
    },
    destroy() {
      void doc.destroy();
    },
  };
}
