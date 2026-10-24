// Exports the lighting companion's curated fixture library and gels to JSON
// for TitanDeck's Companion tab. Run from the lighting-companion folder so its
// Vite aliases resolve:
//
//   cd lighting-companion && npx vite-node ../TitanDeck/Tools/export_companion_data.ts
//
// Writes TitanDeck/Resources/Companion/fixtures.json and gels.json. Timestamps
// are left out so re-running only changes the files when the data changes.
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { seedFixtures } from '@/data/fixtures';
import { seedGels } from '@/data/gels';

const out = resolve(process.cwd(), '../TitanDeck/Resources/Companion');

const fixtures = seedFixtures().map(({ createdAt, updatedAt, ...fixture }) => fixture);
writeFileSync(resolve(out, 'fixtures.json'), JSON.stringify(fixtures, null, 1) + '\n');
const gels = seedGels().map(({ createdAt, updatedAt, ...gel }) => gel);
writeFileSync(resolve(out, 'gels.json'), JSON.stringify(gels, null, 1) + '\n');

console.log(`${fixtures.length} fixtures, ${gels.length} gels -> ${out}`);
