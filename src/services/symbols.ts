import type { Fixture } from '@/models/fixture';

/**
 * Lighting-plot symbols, generated as SVG.
 *
 * Every fixture maps to a symbol family (Fresnel, open-face COB, profile, PAR,
 * panel, tube, moving head, bulb, flood) drawn top-down with the lens/output
 * edge facing down the page, the way plot symbols are conventionally laid out.
 * Generating them (rather than shipping bitmaps) keeps the app offline-light,
 * scales cleanly for print, and lets us export SVG or PNG for a console's
 * symbol/image pool or a CAD plot.
 */

export type SymbolKind =
  | 'fresnel'
  | 'cob'
  | 'profile'
  | 'par'
  | 'panel'
  | 'tube'
  | 'movinghead'
  | 'bulb'
  | 'flood';

export const SYMBOL_LABELS: Record<SymbolKind, string> = {
  fresnel: 'Fresnel',
  cob: 'Open-face COB',
  profile: 'Profile / spot',
  par: 'PAR',
  panel: 'Panel / soft',
  tube: 'Tube / bar',
  movinghead: 'Moving head',
  bulb: 'Bulb',
  flood: 'Flood',
};

/** Work out which plot symbol a fixture should use from its category + model. */
export function symbolKindFor(f: Pick<Fixture, 'model' | 'category'>): SymbolKind {
  const cat = f.category ?? '';
  const hay = `${cat} ${f.model}`;
  if (/moving head/i.test(cat)) return 'movinghead';
  if (/tube|wand|stick|pixelbar|infinibar|pipeline|\bbar\b/i.test(hay)) return 'tube';
  if (/bulb|lightdrop|nyx/i.test(hay)) return 'bulb';
  if (/\bpar\b|powerpar|triplepar/i.test(hay)) return 'par';
  if (/profile|ellipsoidal|source four|spotmax|focusing|\bspot\b/i.test(hay)) return 'profile';
  if (/panel|soft|flex|mat\b|skypanel|gemini|puck|brick/i.test(hay)) return 'panel';
  if (/flood/i.test(hay)) return 'flood';
  if (/cob/i.test(cat)) return 'cob';
  return 'fresnel';
}

// Body fill is a light tint so symbols read on both dark UI and white paper.
const BODY = 'fill="currentColor" fill-opacity="0.12"';

const shapes: Record<SymbolKind, string> = {
  // Housing, yoke ears, stepped Fresnel lens at the output edge.
  fresnel: `
    <path d="M10 22h4M50 22h4" />
    <rect x="14" y="8" width="36" height="34" rx="4" ${BODY} />
    <path d="M14 42h36v8H14z" ${BODY} />
    <path d="M20 46h24M24 50v-8M32 50v-8M40 50v-8" />`,
  // Small head with a flared reflector bowl.
  cob: `
    <path d="M10 18h4M50 18h4" />
    <rect x="20" y="6" width="24" height="18" rx="3" ${BODY} />
    <path d="M18 24h28l10 26H8z" ${BODY} />
    <path d="M14 50h36" />`,
  // Long lamp housing, shutter ring, lens barrel narrowing to the front.
  profile: `
    <path d="M14 20h4M46 20h4" />
    <rect x="18" y="4" width="28" height="26" rx="4" ${BODY} />
    <path d="M16 30h32v5H16z" ${BODY} />
    <path d="M20 35h24l-3 21H23z" ${BODY} />`,
  // Round can with lens and centre.
  par: `
    <path d="M6 32h4M54 32h4" />
    <circle cx="32" cy="32" r="22" ${BODY} />
    <circle cx="32" cy="32" r="13" />
    <circle cx="32" cy="32" r="3" fill="currentColor" />`,
  // Wide face with an emitter grid.
  panel: `
    <path d="M32 8v6" />
    <rect x="6" y="14" width="52" height="38" rx="4" ${BODY} />
    <path d="M23.3 14v38M40.6 14v38M6 33h52" />`,
  // Long tube with pixel segments.
  tube: `
    <rect x="3" y="25" width="58" height="14" rx="7" ${BODY} />
    <path d="M13 25v14M23 25v14M33 25v14M43 25v14M53 25v14" />`,
  // Base, yoke and head.
  movinghead: `
    <rect x="14" y="48" width="36" height="10" rx="3" ${BODY} />
    <path d="M18 48V24M46 48V24" />
    <circle cx="32" cy="26" r="14" ${BODY} />
    <circle cx="32" cy="26" r="7" />`,
  // Lamp with radiating output.
  bulb: `
    <circle cx="32" cy="28" r="14" ${BODY} />
    <path d="M26 42h12v8H26z" ${BODY} />
    <path d="M32 6v4M12 28h4M48 28h4M17 13l3 3M47 13l-3 3" />`,
  // Shallow wide reflector.
  flood: `
    <path d="M10 18h4M50 18h4" />
    <rect x="16" y="8" width="32" height="14" rx="3" ${BODY} />
    <path d="M14 22h36l8 26H6z" ${BODY} />
    <path d="M6 48h52" />`,
};

export interface SymbolOptions {
  /** Stroke colour (hex). Defaults to currentColor for in-app theming. */
  color?: string;
  /** Optional caption drawn under the symbol (e.g. "Key 1" or the model). */
  label?: string;
  /** Rendered pixel size of the square symbol area. */
  size?: number;
}

const escapeXml = (s: string) =>
  s.replace(/[<>&"']/g, (c) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;' })[c]!);

/** Standalone SVG markup for a symbol — usable inline or as a downloaded file. */
export function symbolSvg(kind: SymbolKind, opts: SymbolOptions = {}): string {
  const { color = 'currentColor', label, size = 64 } = opts;
  const h = label ? 80 : 64;
  const caption = label
    ? `<text x="32" y="75" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="9" font-weight="600" fill="${color}" stroke="none">${escapeXml(label)}</text>`
    : '';
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 ${h}" width="${size}" height="${(size * h) / 64}" ` +
    `fill="none" stroke="${color}" color="${color}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">` +
    shapes[kind] +
    caption +
    `</svg>`
  );
}

export function symbolFilename(f: Pick<Fixture, 'manufacturer' | 'model'>, ext: 'svg' | 'png'): string {
  const slug = `${f.manufacturer}-${f.model}`.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  return `${slug}.${ext}`;
}

/** Rasterise a symbol to a PNG blob (browser only). */
export async function symbolPng(kind: SymbolKind, opts: SymbolOptions & { background?: string } = {}): Promise<Blob> {
  const size = opts.size ?? 256;
  const svg = symbolSvg(kind, { ...opts, size, color: opts.color ?? '#111111' });
  const url = URL.createObjectURL(new Blob([svg], { type: 'image/svg+xml' }));
  try {
    const img = new Image();
    img.src = url;
    await img.decode();
    const canvas = document.createElement('canvas');
    canvas.width = img.width;
    canvas.height = img.height;
    const ctx = canvas.getContext('2d')!;
    if (opts.background) {
      ctx.fillStyle = opts.background;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    }
    ctx.drawImage(img, 0, 0);
    return await new Promise<Blob>((resolve, reject) =>
      canvas.toBlob((b) => (b ? resolve(b) : reject(new Error('PNG encode failed'))), 'image/png'),
    );
  } finally {
    URL.revokeObjectURL(url);
  }
}

/** Trigger a download of a blob or text payload. */
export function downloadFile(data: Blob | string, filename: string, type = 'text/plain'): void {
  const blob = typeof data === 'string' ? new Blob([data], { type }) : data;
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
