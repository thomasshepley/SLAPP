# Shepley Lighting Companion

Offline-first PWA companion for on-set lighting work with grandMA3 and Avolites
Titan. Built to run in Safari on an iPad, installable to the home screen, fully
usable with no network on set.

> **Status: v0.1 scaffold.** The foundation is in place — data model, IndexedDB
> storage layer, console adapter contract, and the pure calculation engines
> (stops, photometry, colour, exposure, power, address packing) with tests. UI
> screens are intentionally next, built one section at a time on top of this.
> See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and the feature brief in
> [`docs/FEATURES.md`](docs/FEATURES.md).

## Getting started

```bash
npm install
npm run dev        # local dev server
npm run typecheck  # tsc, no emit
npm test           # vitest — calculation engines
npm run build      # production PWA build
```

## Project layout

```
src/
  models/     Domain types (the shared contract)
  db/         Dexie IndexedDB schema + repositories
  services/   Calculation engines + console/GDTF/PDF integrations
  features/   UI per brief section (placeholder shell for now)
  styles/     Global CSS
docs/         Architecture + feature brief
```

## Scope at a glance

Console integration (MA3 / Titan) · show & job management · local fixture
library with GDTF sync · new-showfile macro with auto-addressing · stops
calculator · Polycam plot tagging · colour tools · camera/exposure tools ·
photometry & beam tools · power tools · on-set reference tools. Full detail in
`docs/FEATURES.md`.
