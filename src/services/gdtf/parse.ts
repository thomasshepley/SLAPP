import { unzipSync, strFromU8 } from 'fflate';
import { XMLParser } from 'fast-xml-parser';
import { mapGdtfAttribute } from './attributeMap';
import { DEFAULT_PHOTOMETRY_KEY, type Fixture, type FixtureMode, type ChannelFunction } from '@/models/fixture';
import { now, type FixtureId } from '@/models/common';

/**
 * Parses a .gdtf archive into a library Fixture. GDTF is a ZIP containing
 * description.xml (the General Device Type Format). We extract the bits the app
 * uses — manufacturer/model, DMX modes + channels, beam angle, power — and map
 * GDTF's attribute vocabulary onto our canonical roles. Photometry (lux@1m)
 * isn't reliably encoded in GDTF, so it's left for the user to fill in; the
 * dimming curve defaults to linear.
 *
 * The pure object→Fixture logic lives in `gdtfDocToFixture` so it can be unit
 * tested without unzipping. `parseGdtf` is the thin binary entry point.
 */

export interface ParsedGdtf {
  fixture: Fixture;
  warnings: string[];
}

const xmlParser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  // GDTF nests repeatable elements; force arrays so single/multi are uniform.
  isArray: (name) =>
    ['DMXMode', 'DMXChannel', 'LogicalChannel', 'ChannelFunction', 'Geometry', 'Beam'].includes(name),
});

export function parseGdtf(data: ArrayBuffer): ParsedGdtf {
  const files = unzipSync(new Uint8Array(data));
  const descKey = Object.keys(files).find((k) => k.toLowerCase().endsWith('description.xml'));
  if (!descKey) throw new Error('Not a valid GDTF: no description.xml inside the archive.');
  const xml = strFromU8(files[descKey]!);
  const doc = xmlParser.parse(xml);
  return gdtfDocToFixture(doc);
}

/** Pure: parsed-XML object → Fixture. Exported for tests. */
export function gdtfDocToFixture(doc: unknown): ParsedGdtf {
  const warnings: string[] = [];
  const root = (doc as Record<string, any>)?.GDTF ?? (doc as Record<string, any>);
  const ft = root?.FixtureType;
  if (!ft) throw new Error('GDTF has no FixtureType element.');

  const manufacturer = String(ft['@_Manufacturer'] ?? 'Unknown').trim();
  const model = String(ft['@_Name'] ?? ft['@_ShortName'] ?? 'Unknown fixture').trim();

  // --- Modes & channels ---
  const rawModes: any[] = ft.DMXModes?.DMXMode ?? [];
  const modes: FixtureMode[] = [];
  for (const m of rawModes) {
    const channels = extractChannels(m);
    const channelCount = channels.reduce((max, c) => Math.max(max, c.offset + 1), 0);
    modes.push({
      name: String(m['@_Name'] ?? `Mode ${modes.length + 1}`),
      channelCount: channelCount || channels.length,
      channels,
      powerW: extractPower(ft),
    });
  }
  if (modes.length === 0) {
    warnings.push('No DMX modes found; created an empty 1-channel mode.');
    modes.push({ name: 'Default', channelCount: 1, channels: [] });
  }

  const beamAngle = extractBeamAngle(ft);
  if (beamAngle === undefined) warnings.push('No beam angle in GDTF; left blank.');

  const cri = extractCri(ft);

  const fixture: Fixture = {
    id: makeFixtureId(manufacturer, model),
    manufacturer,
    model,
    category: extractCategory(ft),
    modes,
    photometry: {
      [DEFAULT_PHOTOMETRY_KEY]: { dimmingCurve: { type: 'linear' } },
    },
    colour: {
      ...(cri !== undefined ? { cri } : {}),
      hasColourMixing: modes.some((m) =>
        m.channels.some((c) => ['red', 'green', 'blue', 'cyan', 'magenta', 'yellow'].includes(c.attribute)),
      ),
    },
    beam: beamAngle !== undefined ? { angleDeg: beamAngle } : {},
    schemaVersion: 1,
    userModified: false,
    source: {
      origin: 'gdtf-share',
      gdtfFixtureTypeId: ft['@_FixtureTypeID'] ? String(ft['@_FixtureTypeID']) : undefined,
    },
    createdAt: now(),
    updatedAt: now(),
  };

  return { fixture, warnings };
}

function extractChannels(mode: any): ChannelFunction[] {
  const raw: any[] = mode.DMXChannels?.DMXChannel ?? [];
  const channels: ChannelFunction[] = [];
  for (const ch of raw) {
    const offsets = parseOffsets(ch['@_Offset']);
    if (offsets.length === 0) continue; // virtual channel, no DMX footprint
    const logical = ch.LogicalChannel?.[0] ?? ch.LogicalChannel;
    const fn = logical?.ChannelFunction?.[0] ?? logical?.ChannelFunction;
    const gdtfAttr = String(
      logical?.['@_Attribute'] ?? fn?.['@_Attribute'] ?? ch['@_Attribute'] ?? '',
    );
    const attribute = mapGdtfAttribute(gdtfAttr);
    const coarse = Math.min(...offsets) - 1; // GDTF offsets are 1-based
    channels.push({
      offset: coarse,
      resolution: offsets.length > 1 ? 16 : 8,
      attribute,
      label: gdtfAttr || ch['@_Geometry'] || `Ch ${coarse + 1}`,
    });
  }
  return channels.sort((a, b) => a.offset - b.offset);
}

/** GDTF Offset is a comma list of 1-based DMX channels, e.g. "1,2" for 16-bit. */
function parseOffsets(offset: unknown): number[] {
  if (offset === undefined || offset === null || offset === 'None' || offset === '') return [];
  return String(offset)
    .split(',')
    .map((s) => Number(s.trim()))
    .filter((n) => Number.isFinite(n) && n > 0);
}

function extractBeamAngle(ft: any): number | undefined {
  const geometries = collectGeometries(ft.Geometries);
  for (const g of geometries) {
    const beams: any[] = g.Beam ?? [];
    for (const b of beams) {
      const angle = Number(b['@_BeamAngle']);
      if (Number.isFinite(angle) && angle > 0) return Math.round(angle);
    }
  }
  return undefined;
}

function collectGeometries(node: any): any[] {
  if (!node) return [];
  const out: any[] = [];
  const walk = (n: any) => {
    if (!n || typeof n !== 'object') return;
    for (const [key, val] of Object.entries(n)) {
      if (key.startsWith('@_')) continue;
      const arr = Array.isArray(val) ? val : [val];
      for (const item of arr) {
        if (item && typeof item === 'object') {
          out.push(item);
          walk(item);
        }
      }
    }
  };
  walk(node);
  return out;
}

function extractPower(ft: any): number | undefined {
  const geometries = collectGeometries(ft.Geometries);
  for (const g of geometries) {
    const p = Number(g['@_PowerConsumption']);
    if (Number.isFinite(p) && p > 0) return Math.round(p);
  }
  return undefined;
}

function extractCri(ft: any): number | undefined {
  // GDTF stores CRI groups under PhysicalDescriptions; surface a single Ra if present.
  const cri = ft.PhysicalDescriptions?.CRIs?.CRIGroup?.CRI;
  const arr = Array.isArray(cri) ? cri : cri ? [cri] : [];
  const values = arr.map((c: any) => Number(c['@_ColorRenderingIndex'])).filter(Number.isFinite);
  if (values.length === 0) return undefined;
  return Math.round(values.reduce((a: number, b: number) => a + b, 0) / values.length);
}

function extractCategory(ft: any): string | undefined {
  const refined = ft['@_RefinedFixtureType'] ?? ft['@_FixtureType'];
  return refined ? String(refined) : undefined;
}

function makeFixtureId(manufacturer: string, model: string): FixtureId {
  const slug = `${manufacturer}-${model}`
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
  return `fx-gdtf-${slug}` as FixtureId;
}
