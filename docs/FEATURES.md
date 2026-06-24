# Shepley Lighting Companion — Feature List v0.1

## Platform & Architecture
- PWA, runs in Safari on iPad, installable to home screen
- Fully client-side — no server dependency on set
- IndexedDB for all local storage (fixture library, job prefs, cached files)
- GDTF sync performed at home over internet before going on site
- Connects to MA3 HTTP API (dedicated console) and Titan Remote HTTP API (Titan Mobile / Windows PC) over local lighting network WAP
- Per-job configuration with saved preferences

## 1. Console Integration

### MA3
- Connect to MA3 HTTP API by IP
- Pull current patch (fixture type, universe, address, mode)
- Pull current intensities per fixture
- Push patch data (new showfile macro)
- Query fixture types against local GDTF library

### Titan (Titan Mobile / onPC)
- Connect to Titan Remote HTTP API by IP
- Pull current patch
- Pull current intensities
- Push patch data
- Query fixture types against local GDTF library

### General
- Switchable active console (MA3 / Titan) per job
- Connection status indicator, auto-reconnect
- Read-only mode if no console connected (app still fully usable offline)

## 2. Show Management

### Save & Open Shows
- Save current job/show state to local storage at any time
- Named saves with timestamp and optional notes
- Open saved show — restores all job settings, fixture list, patch, universe prefs, plot annotations
- Auto-save prompt on switching jobs or closing

### Show Library
- List of all saved shows, sortable by date / name
- Duplicate a show as a starting point for a similar job
- Delete with confirmation
- Export show as a portable file (JSON bundle) for backup or transfer to another device

### Cross-Show Import Tool
- Open any saved show alongside the current show
- Browse the saved show's contents: patch, universe preference profile, power budget, notes
- Selectively import into current show: full patch or individual fixture types, universe profile; merge or replace with conflict warnings
- Useful for recurring venues, standing rigs, or starting from a previous tour's patch

## 3. Fixture Library
- Curated list of commonly used fixtures, user-expandable
- GDTF files stored locally after sync
- Per-fixture stored data: DMX modes and channel maps, photometric data / dimming curve, CRI and TLCI, beam angle(s), power draw per mode, weight, linked manual PDF, linked DMX table PDF
- GDTF sync: specify preferred brands, app fetches latest GDTF from GDTF-Share on next sync
- Manual PDF and DMX table storage local on device
- Fixture comparator — compare two fixtures side by side

## 4. New Showfile Macro
- Select console (MA3 or Titan)
- Build fixture list from library — type, mode, quantity
- Per-job universe preference: wireless vs copper DMX universes, assign fixture types
- App calculates addresses automatically, packs sequentially, flags universe overflow
- Pushes patch to console via API
- Generates cheat sheet (printable / shareable PDF) with per-fixture address list and QR codes to manuals
- Generates test pattern sequence suggestion
- Saved as part of the show on completion

## 5. Stops Calculator
- Pulls live fixture list and intensities from active console
- Per fixture, uses photometric dimming curve to calculate current lux (at 1m), and DMX value for +1/+2/-1/-2 stops, shown as DMX and percentage
- Manual mode if no console connected
- Handles non-linear / square law / log dimming curves

## 6. Polycam Plot Import
- Import Polycam PDF export, rendered in-app
- User manually tags fixtures on the plot by tapping; assign type, label, position notes
- Tagged plot saved with show, informs patch order, exportable as annotated PDF
- Acknowledged limitation: PDF parsing is visual not structural, so tagging is manual

## 7. Colour Tools
- Gel search (name, number, manufacturer, colour); filter by Rosco/Lee/GAM; transmission curve where available
- Gel → RGB / HSI for LED fixtures, accounting for white point
- CTO / CTB calculator (source/target CCT → gel + mired shift, bidirectional)
- Colour temperature ↔ mired converter with reference table
- Duv / tint display relative to Planckian locus
- Percentage → CCT for variable-CCT fixtures

## 8. Camera & Exposure Tools
- Exposure calculator (lux → EV, aperture/ISO/shutter suggestions)
- Flicker-free shutter calculator (frame rate + mains freq → safe shutter angles/speeds)
- ND filter stack calculator (forward and reverse)
- CRI / TLCI reference per fixture

## 9. Photometry & Beam Tools
- Inverse square law calculator (bidirectional)
- Beam coverage calculator (beam angle + throw → diameter; across zoom range)
- Throw distance reference per fixture

## 10. Power Tools
- Power budget calculator (fixtures × quantity → W and A at 230V, flag over distro; pull from console patch)
- Cable derating reference (capacity vs CSA, run length, ambient temp)

## 11. On-Set Reference Tools
- Sun position & golden hour (manual location entry, sunrise/sunset/golden/blue hour, azimuth/elevation)
- Gobo rotation speed ↔ BPM sync
- DMX table browser per fixture (searchable, PDF or parsed GDTF)
- Manual browser per fixture (PDF, quick-launch)

## 12. Job Management
- Create and save jobs (console + IP, universe profile, fixture list, plot, cheat sheet, power budget, notes)
- Switch between jobs
- Export job pack as PDF (plot, patch, cheat sheet, power budget)
- All jobs feed into Show Management (Section 2)
