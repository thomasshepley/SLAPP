# Shepley Lighting Companion

Offline-first PWA companion for on-set lighting work with grandMA3 and Avolites
Titan. Built to run in Safari on an iPad, installable to the home screen, fully
usable with no network on set.

> **Status: v0.2 — most features working, offline.** 10 of the 12 brief
> sections are built as working UI on a tested foundation. See
> [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and the brief in
> [`docs/FEATURES.md`](docs/FEATURES.md).
>
> **Working now (all offline, no hardware needed):** Shows (save / open /
> duplicate / export / import / cross-import), Fixture library + comparator,
> New Showfile macro (auto-addressing + printable cheat sheet), Stops
> calculator (manual), Colour tools, Camera & exposure tools, Photometry &
> beam tools, Power tools, On-set reference (sun position, gobo BPM), Polycam
> plot import + tagging.
>
> **Not yet wired (needs physical hardware / API access to build & verify):**
> live MA3 / Titan console integration (§1) and GDTF-Share network sync. The
> console adapter contract and neutral data types are in place; the adapters
> are documented stubs so the app runs fully in offline / read-only mode.

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
