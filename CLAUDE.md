# SLAPP - notes for Claude

Shepley lighting apps for TV, film and live music work. The owner is a lighting
tech with basic-to-mid web dev experience. Explain things briefly and keep it
conversational.

| Folder | What | Status |
| --- | --- | --- |
| `TitanDeck/` | Native SwiftUI iPad app: Stream Deck -> Avolites Titan playbacks, plus an RDP view of the Titan PC | **Active**. Read `TitanDeck/CLAUDE.md` before working on it. |
| `lighting-companion/` | Offline React/Vite PWA: fixture library, stops/photometry/power tools, showfile macro, plot tagging | **Sidelined**. Don't change it unless asked. It will be rebuilt into TitanDeck later. |

## Repo-wide rules

- Regular hyphens only, never em dashes.
- Work on a branch, never commit straight to `main`.
- `.github/workflows/titandeck.yml` builds/tests TitanDeck on macOS runners and
  uploads `main` builds to TestFlight. `.github/workflows/deploy.yml` deploys the
  lighting companion to GitHub Pages from `main`.
- No secrets in git.
