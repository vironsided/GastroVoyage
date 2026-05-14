/**
 * GastroVoyage — pre-bake the world map shapes for the Skia canvas.
 *
 * Reads world-atlas 50m TopoJSON, projects every country with
 * d3-geo's geoNaturalEarth1 into a normalized 0..1 coordinate space,
 * and writes the result to packages/shared/src/data/world-shapes.json.
 *
 * This means the mobile app does ZERO d3 work at runtime — Skia just
 * draws prebaked SVG path strings.
 *
 * Run:   node tools/generate-country-shapes.mjs
 * Output:
 *   packages/shared/src/data/world-shapes.json
 *
 * Dependencies (installed temporarily — not added to the app deps):
 *   world-atlas, d3-geo, topojson-client
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { feature } = require('topojson-client');
const { geoNaturalEarth1, geoPath, geoBounds, geoCentroid } = require('d3-geo');
const worldTopo = require('world-atlas/countries-50m.json');

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const countriesPath = path.join(root, 'packages/shared/src/data/countries.json');
const outPath = path.join(root, 'packages/shared/src/data/world-shapes.json');

// Our existing ISO master list — we use it to attach iso_a2 and to filter to UN members.
const ourCountries = JSON.parse(fs.readFileSync(countriesPath, 'utf8'));
const isoA3ToOurs = new Map(ourCountries.map((c) => [c.iso_a3, c]));

// world-atlas 50m uses ISO numeric 3-digit codes (e.g. "643" Russia).
// The `properties.name` is included, but no ISO codes. We need a mapping.
// Workaround: use the 'id' field which is the ISO numeric code, then look up via
// our world-countries data (which has numeric codes via the original source).
// Simpler approach: use the country NAME match against our list.
//
// Even simpler: use the `naturalearth-1` flavor of countries-50m which has alpha codes
// in properties. The standard world-atlas package only has names + numeric ids though.
// We'll do name-based matching with a few hardcoded aliases.

// Maps world-atlas feature names -> our canonical countries.json `name`.
// `null` = intentionally skip (not in our list; territory, disputed, or non-UN).
const NAME_ALIASES = {
  // -- Core renames -----------------------------------------------------------
  'United States of America': 'United States',
  'United Republic of Tanzania': 'Tanzania',
  'Dem. Rep. Congo': 'DR Congo',
  'Democratic Republic of the Congo': 'DR Congo',
  Congo: 'Republic of the Congo',
  'Republic of the Congo': 'Republic of the Congo',
  'Czech Rep.': 'Czechia',
  'Russian Federation': 'Russia',
  'Iran (Islamic Republic of)': 'Iran',
  "Lao People's Democratic Republic": 'Laos',
  'Lao PDR': 'Laos',
  "Dem. People's Rep. Korea": 'North Korea',
  "Korea, Dem. People's Rep.": 'North Korea',
  "Democratic People's Republic of Korea": 'North Korea',
  'Republic of Korea': 'South Korea',
  'Korea, Republic of': 'South Korea',
  'Syrian Arab Republic': 'Syria',
  'Bolivia (Plurinational State of)': 'Bolivia',
  'Venezuela (Bolivarian Republic of)': 'Venezuela',
  'Republic of Moldova': 'Moldova',
  'The former Yugoslav Republic of Macedonia': 'North Macedonia',
  Macedonia: 'North Macedonia',
  Swaziland: 'Eswatini',
  eSwatini: 'Eswatini',
  Burma: 'Myanmar',
  "Cote d'Ivoire": 'Ivory Coast',
  "Côte d'Ivoire": 'Ivory Coast',
  'Viet Nam': 'Vietnam',
  'Brunei Darussalam': 'Brunei',
  'Federated States of Micronesia': 'Micronesia',
  'Micronesia (Federated States of)': 'Micronesia',
  'Cabo Verde': 'Cape Verde',
  'East Timor': 'Timor-Leste',
  'Republic of Serbia': 'Serbia',
  Turkey: 'Türkiye',
  'Turkey ': 'Türkiye',
  'Bosnia and Herz.': 'Bosnia and Herzegovina',
  'Central African Rep.': 'Central African Republic',
  'Dominican Rep.': 'Dominican Republic',
  'Eq. Guinea': 'Equatorial Guinea',
  'S. Sudan': 'South Sudan',
  'Sao Tome and Principe': 'São Tomé and Príncipe',
  'São Tomé and Principe': 'São Tomé and Príncipe',
  'St. Vin. and Gren.': 'Saint Vincent and the Grenadines',
  'St. Kitts and Nevis': 'Saint Kitts and Nevis',
  'Antigua and Barb.': 'Antigua and Barbuda',
  'Solomon Is.': 'Solomon Islands',
  'Faeroe Is.': 'Faroe Islands', // not in our list but harmless if matched -> null
  'Holy See': null,
  Vatican: null,
  'Vatican City': null,

  // -- Intentional skips: territories, disputed, non-UN -----------------------
  'W. Sahara': null,
  'Western Sahara': null,
  'N. Cyprus': null,
  'Falkland Is.': null,
  'Fr. S. Antarctic Lands': null,
  Antarctica: null,
  Greenland: null,
  'Marshall Is.': 'Marshall Islands',
  'N. Mariana Is.': null,
  'U.S. Virgin Is.': null,
  Guam: null,
  'American Samoa': null,
  'Puerto Rico': null,
  'S. Geo. and the Is.': null,
  'Br. Indian Ocean Ter.': null,
  'Saint Helena': null,
  'Pitcairn Is.': null,
  Anguilla: null,
  'Cayman Is.': null,
  Bermuda: null,
  'British Virgin Is.': null,
  'Turks and Caicos Is.': null,
  Montserrat: null,
  Jersey: null,
  Guernsey: null,
  'Isle of Man': null,
  Taiwan: null,
  Somaliland: null,
  Niue: null,
  'Cook Is.': null,
  Aruba: null,
  Curaçao: null,
  Kosovo: null,
  Palestine: null,
  'St. Pierre and Miquelon': null,
  'Wallis and Futuna Is.': null,
  'St-Martin': null,
  'St-Barthélemy': null,
  'Fr. Polynesia': null,
  'New Caledonia': null,
  Åland: null,
  'Faeroe Is.': null,
  Macao: null,
  'Hong Kong': null,
  'Indian Ocean Ter.': null,
  'Heard I. and McDonald Is.': null,
  'Norfolk Island': null,
  'Ashmore and Cartier Is.': null,
  'Siachen Glacier': null,
  'Sint Maarten': null,
};

// Convert TopoJSON -> GeoJSON FeatureCollection
const fc = feature(worldTopo, worldTopo.objects.countries);
console.log(`Loaded ${fc.features.length} country features from world-atlas 50m.`);

// Build a name index for our countries (case-insensitive)
const nameToOurs = new Map();
for (const c of ourCountries) {
  nameToOurs.set(c.name.toLowerCase(), c);
}

function matchToOurs(featureName) {
  if (featureName == null) return null;
  const alias = NAME_ALIASES[featureName];
  if (alias === null) return null; // explicit skip
  const target = (alias ?? featureName).toLowerCase();
  return nameToOurs.get(target) ?? null;
}

// ---------- projection ----------
// Use unit projection: we want output in normalized 0..1 space.
// d3 geoPath uses a projection that maps lng/lat to pixels. We give it
// a fitted projection: scale + translate so the world fills a 1000x1000
// box, then divide by 1000 to normalize.

const VIRT_W = 1000;
const VIRT_H = 500;

const projection = geoNaturalEarth1();
projection.fitExtent(
  [
    [0, 0],
    [VIRT_W, VIRT_H],
  ],
  fc,
);

// Custom geoPath with a small "rounding" context to reduce file size.
// We round coordinates to 1 decimal — plenty in a 1000x500 normalized space.
const pathGen = geoPath(projection);

function roundPath(pathStr) {
  if (!pathStr) return pathStr;
  // Replace every decimal number with a 1-decimal rounded version.
  return pathStr.replace(/-?\d+\.\d+/g, (m) => {
    const n = parseFloat(m);
    return (Math.round(n * 10) / 10).toString();
  });
}

const out = {
  width: VIRT_W,
  height: VIRT_H,
  features: [],
};

let matched = 0;
let skipped = 0;
const unmatchedNames = [];

for (const f of fc.features) {
  const name = f.properties?.name ?? null;
  const ours = matchToOurs(name);
  if (!ours) {
    skipped++;
    if (NAME_ALIASES[name] !== null) unmatchedNames.push(name);
    continue;
  }

  const pathStr = pathGen(f);
  if (!pathStr) {
    skipped++;
    continue;
  }

  // Centroid (in projected pixel space)
  const cxy = pathGen.centroid(f);
  const [cx, cy] = cxy;

  // Bounding box: geoBounds returns [[lng, lat], [lng, lat]] of unprojected;
  // we want the projected bbox. Use pathGen.bounds which returns [[x, y], [x, y]].
  const [[minX, minY], [maxX, maxY]] = pathGen.bounds(f);

  out.features.push({
    iso_a2: ours.iso_a2,
    iso_a3: ours.iso_a3,
    name: ours.name,
    region: ours.region,
    path: roundPath(pathStr),
    cx: round(cx),
    cy: round(cy),
    minX: round(minX),
    minY: round(minY),
    maxX: round(maxX),
    maxY: round(maxY),
  });
  matched++;
}

function round(n) {
  return Math.round(n * 100) / 100;
}

// Sort by region then name for deterministic output
out.features.sort((a, b) => {
  if (a.region !== b.region) return a.region.localeCompare(b.region);
  return a.name.localeCompare(b.name);
});

fs.writeFileSync(outPath, JSON.stringify(out));
console.log(`Wrote ${outPath}`);
console.log(`  matched: ${matched}`);
console.log(`  skipped (incl intentional): ${skipped}`);
if (unmatchedNames.length) {
  console.log(`  unmatched (consider adding alias):`);
  for (const n of unmatchedNames) console.log(`    - ${n}`);
}
console.log(`  file size: ${(fs.statSync(outPath).size / 1024).toFixed(1)} KB`);
