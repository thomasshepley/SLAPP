import type { Degrees } from '@/models/common';

/**
 * Sun position & golden/blue hour. Location is entered manually (no GPS, per
 * the brief). Implements the standard NOAA solar position algorithm; results
 * are accurate to well within a minute for normal latitudes — plenty for call
 * sheets and shot planning.
 *
 * All times are returned as minutes from local midnight (0..1440) so the UI can
 * format them against whatever the device clock / job timezone is. Pass the
 * location's UTC offset in hours to anchor them to local wall-clock time.
 */

export interface SunInput {
  date: Date;
  latitude: Degrees;
  longitude: Degrees;
  /** Location UTC offset in hours, e.g. +1 for BST, -8 for PST. */
  utcOffsetHours: number;
}

export interface SunTimes {
  sunriseMin: number | null; // null = sun never rises (polar)
  sunsetMin: number | null;
  solarNoonMin: number;
  goldenHourMorning: TimeRange | null; // sunrise → sun at +6°
  goldenHourEvening: TimeRange | null; // sun at +6° → sunset
  blueHourMorning: TimeRange | null; // sun -6° → -4° (civil-ish)
  blueHourEvening: TimeRange | null;
}

export interface TimeRange {
  startMin: number;
  endMin: number;
}

export interface SunPosition {
  azimuth: Degrees; // 0 = north, 90 = east, clockwise
  elevation: Degrees; // 0 = horizon, 90 = zenith
}

const rad = (d: number): number => (d * Math.PI) / 180;
const deg = (r: number): number => (r * 180) / Math.PI;

/** Days since the J2000.0 epoch for a given instant. */
function julianDay(date: Date): number {
  return date.getTime() / 86_400_000 + 2_440_587.5;
}

/** Solar declination and equation of time for a date (NOAA approximation). */
function solarParams(date: Date): { declDeg: number; eqTimeMin: number } {
  const jd = julianDay(date);
  const t = (jd - 2_451_545) / 36_525; // Julian centuries since J2000
  const l0 = mod360(280.46646 + t * (36_000.76983 + t * 0.0003032));
  const m = 357.52911 + t * (35_999.05029 - 0.0001537 * t);
  const e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
  const mRad = rad(m);
  const c =
    Math.sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
    Math.sin(2 * mRad) * (0.019993 - 0.000101 * t) +
    Math.sin(3 * mRad) * 0.000289;
  const trueLong = l0 + c;
  const omega = 125.04 - 1934.136 * t;
  const lambda = trueLong - 0.00569 - 0.00478 * Math.sin(rad(omega));
  const epsilon0 =
    23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
  const epsilon = epsilon0 + 0.00256 * Math.cos(rad(omega));
  const declDeg = deg(Math.asin(Math.sin(rad(epsilon)) * Math.sin(rad(lambda))));

  const y = Math.tan(rad(epsilon / 2)) ** 2;
  const eqTime =
    4 *
    deg(
      y * Math.sin(2 * rad(l0)) -
        2 * e * Math.sin(mRad) +
        4 * e * y * Math.sin(mRad) * Math.cos(2 * rad(l0)) -
        0.5 * y * y * Math.sin(4 * rad(l0)) -
        1.25 * e * e * Math.sin(2 * mRad),
    );
  return { declDeg, eqTimeMin: eqTime };
}

/** Local minute (from midnight) at which the sun reaches a given elevation. */
function timeAtElevation(
  elevationDeg: number,
  morning: boolean,
  input: SunInput,
  declDeg: number,
  eqTimeMin: number,
): number | null {
  const latR = rad(input.latitude);
  const declR = rad(declDeg);
  const cosH =
    (Math.sin(rad(elevationDeg)) - Math.sin(latR) * Math.sin(declR)) /
    (Math.cos(latR) * Math.cos(declR));
  if (cosH > 1 || cosH < -1) return null; // never reaches that elevation today
  const haDeg = deg(Math.acos(cosH)); // hour angle in degrees
  const noon = solarNoonMinutes(input, eqTimeMin);
  const offsetMin = (haDeg / 15) * 60;
  return morning ? noon - offsetMin : noon + offsetMin;
}

function solarNoonMinutes(input: SunInput, eqTimeMin: number): number {
  // Local solar noon corrected for longitude vs the timezone meridian.
  return 720 - 4 * input.longitude - eqTimeMin + input.utcOffsetHours * 60;
}

const SUNRISE_ELEVATION = -0.833; // standard refraction + solar radius
const GOLDEN_ELEVATION = 6;
const BLUE_LOW = -6;
const BLUE_HIGH = -4;

export function sunTimes(input: SunInput): SunTimes {
  const { declDeg, eqTimeMin } = solarParams(input.date);
  const noon = solarNoonMinutes(input, eqTimeMin);
  const at = (el: number, morning: boolean) =>
    timeAtElevation(el, morning, input, declDeg, eqTimeMin);

  const sunrise = at(SUNRISE_ELEVATION, true);
  const sunset = at(SUNRISE_ELEVATION, false);
  const goldenStartAm = sunrise;
  const goldenEndAm = at(GOLDEN_ELEVATION, true);
  const goldenStartPm = at(GOLDEN_ELEVATION, false);
  const goldenEndPm = sunset;
  const blueLowAm = at(BLUE_LOW, true);
  const blueHighAm = at(BLUE_HIGH, true);
  const blueHighPm = at(BLUE_HIGH, false);
  const blueLowPm = at(BLUE_LOW, false);

  const range = (a: number | null, b: number | null): TimeRange | null =>
    a !== null && b !== null ? { startMin: a, endMin: b } : null;

  return {
    sunriseMin: sunrise,
    sunsetMin: sunset,
    solarNoonMin: noon,
    goldenHourMorning: range(goldenStartAm, goldenEndAm),
    goldenHourEvening: range(goldenStartPm, goldenEndPm),
    blueHourMorning: range(blueLowAm, blueHighAm),
    blueHourEvening: range(blueHighPm, blueLowPm),
  };
}

/**
 * Sun azimuth/elevation at a specific instant. Position depends only on the
 * absolute instant (taken in UTC), longitude and latitude — the timezone
 * offset isn't needed here, so the result is independent of the runtime's TZ.
 */
export function sunPosition(input: SunInput): SunPosition {
  const { declDeg, eqTimeMin } = solarParams(input.date);
  const minutes =
    input.date.getUTCHours() * 60 +
    input.date.getUTCMinutes() +
    input.date.getUTCSeconds() / 60;
  // True solar time in minutes (UTC-based; longitude shifts to local solar time).
  const tst = mod(minutes + eqTimeMin + 4 * input.longitude, 1440);
  const haDeg = tst / 4 - 180; // hour angle
  const latR = rad(input.latitude);
  const declR = rad(declDeg);
  const haR = rad(haDeg);

  const elevation = deg(
    Math.asin(
      Math.sin(latR) * Math.sin(declR) + Math.cos(latR) * Math.cos(declR) * Math.cos(haR),
    ),
  );
  let azimuth = deg(
    Math.atan2(
      Math.sin(haR),
      Math.cos(haR) * Math.sin(latR) - Math.tan(declR) * Math.cos(latR),
    ),
  );
  azimuth = mod360(azimuth + 180); // convert to compass bearing from north
  return { azimuth, elevation };
}

const mod = (n: number, m: number): number => ((n % m) + m) % m;
const mod360 = (n: number): number => mod(n, 360);
