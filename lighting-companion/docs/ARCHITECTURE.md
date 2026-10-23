# Architecture — Shepley Lighting Companion

This document is the answer to the brief's closing instruction: *propose the
data models and project structure before writing any UI, so the storage layer
isn't refactored halfway through.* It describes the foundation that is in place
in this scaffold and the conventions UI work should build on top of.

## Principles

1. **Offline-first.** The app must be fully usable on set with no network. The
   app shell is precached by the service worker; all data lives in IndexedDB.
   Console and GDTF-Share calls are the only network use, and both degrade
   gracefully when unavailable.
2. **Layered, UI-last.** Domain types → storage → services (pure logic +
   integrations) → UI. Nothing below the UI layer imports React. This is what
   lets the screens be built incrementally without disturbing the model.
3. **One canonical unit per quantity.** Storage and calculations are metric/SI
   (lux, watts, amps, metres, kelvin). Conversion to imperial/display units
   happens only at the UI edge. See `src/models/common.ts`.
4. **Global library, per-job shows.** The fixture library is shared across all
   jobs; a `Show` is a self-contained job that *references* library fixtures by
   id. This is why fixtures aren't copied into shows — only ids are.

## Layers

```
src/
  models/      Domain types only. No logic, no I/O. The contract everything shares.
  db/          IndexedDB (Dexie) schema + repositories. The only place that touches storage.
  services/    Pure calculation engines + external integrations (console, gdtf, pdf).
  features/    UI, one module per brief section. Currently a navigable placeholder shell.
  components/  Shared UI primitives (added as screens are built).
  hooks/       React hooks bridging services/db to components (added with the UI).
  styles/      Global CSS.
```

### `models/` — the data model

| File | Owns |
| --- | --- |
| `common.ts` | Branded ids, timestamps, unit aliases, DMX primitives. |
| `files.ts` | `StoredFile` (blobs) + `FileRef` indirection. |
| `fixture.ts` | `Fixture`, modes, channel maps, **dimming curves**, photometry, colour quality, beam. |
| `console.ts` | `ConsoleConfig`, connection status, neutral patch/level snapshots. |
| `patch.ts` | `PatchItem`, `UniverseProfile`, packing result types. |
| `plot.ts` | `PolycamPlot` + normalised `PlotTag` coordinates. |
| `power.ts` | `PowerBudget` and its computed result. |
| `colour.ts` | `Gel`, RGB/HSI, transmission curves, chromaticity. |
| `show.ts` | `Show` aggregate, `ShowBundle` export, cross-show import selection. |
| `settings.ts` | App settings + GDTF sync prefs (single row). |

**Key modelling decisions**

- **Show = Job.** The brief's "Show Management" (§2) and "Job Management" (§12)
  are one aggregate (`Show`) viewed two ways. Avoids a second overlapping entity.
- **Dimming curves are first-class.** `DimmingCurve` supports analytic
  (linear/square/scurve/log) *and* `measured` sample points, because the stops
  calculator's correctness depends on modelling real non-linear dimming, not
  assuming linear. This is the model detail most likely to be papered over and
  most expensive to retrofit.
- **Binary assets are separate, referenced by id.** PDFs and GDTF archives live
  in their own table as `Blob`s; domain records hold a lightweight `FileRef`.
  Deleting a show doesn't move megabytes, and one manual can back many fixtures.
- **Branded ids.** `FixtureId`, `ShowId`, … are compile-time-distinct strings,
  so the type checker catches id mix-ups. Zero runtime cost.

### `db/` — storage

Single Dexie database (`database.ts`). **Migration rule: never edit a shipped
`.version(n).stores()` block — add `.version(n+1)` with an `upgrade()`
callback.** Repositories (`repositories/*.ts`) are the only code that calls
Dexie; they own audit-stamp bookkeeping and keep queries out of the UI.

### `services/` — logic & integrations

- `console/` — `ConsoleAdapter` interface normalises MA3 vs Titan to neutral
  types; `ma3Adapter`/`titanAdapter` are staged stubs (transport TODO, mapping
  documented inline); `createConsoleAdapter()` is the factory.
- `calc/` — pure, tested calculation engines: `dimming` (curve eval + inverse),
  `stops`, `photometry` (ISL, beam), `colour` (mired, CTO/CTB, RGB/HSI),
  `exposure` (EV, ND stack, flicker), `power`.
- `patch/packer.ts` — deterministic address-packing for the showfile macro,
  honouring the universe profile and flagging overflow.

## What is intentionally NOT built yet

UI screens, GDTF parsing/sync transport, PDF render/export, and the console HTTP
transports. These all sit on top of the contracts above and can be filled in one
area at a time. The placeholder shell (`features/`) keeps the app navigable
meanwhile.

## Stack

Vite + React + TypeScript, `vite-plugin-pwa` (Workbox) for installable
offline-first PWA, Dexie for IndexedDB, React Router, Vitest for the calc tests.
