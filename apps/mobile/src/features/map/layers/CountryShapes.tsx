import { useMemo } from 'react';
import { Group, Path, Skia, type SkPath } from '@shopify/react-native-skia';
import { useDerivedValue, type SharedValue } from 'react-native-reanimated';
import type { CountryShape } from '@gastrovoyage/shared';

interface Props {
  features: CountryShape[];
  selectedIsoA3: string | null;
  /** 0..1 first-paint progress shared from the parent. */
  paintProgress: SharedValue<number>;
}

interface ParsedFeature {
  iso_a3: string;
  region: string;
  path: SkPath;
  fill: string;
  /** Time offset (0..1) where this country starts fading in. */
  delay: number;
}

const REGION_ORDER = ['Americas', 'Africa', 'Europe', 'Asia', 'Oceania', 'Antarctic'];

const FILL_BASE_H = 41; // Hue of parchment-100 in HSL terms.
const FILL_BASE_S = 48;
const FILL_BASE_L = 82;

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

function colorFor(iso_a3: string): string {
  const h = hash(iso_a3);
  const dh = (h % 12) - 6; // ±6° hue
  const dl = ((h >> 4) % 6) - 3; // ±3% lightness
  return `hsl(${FILL_BASE_H + dh}, ${FILL_BASE_S}%, ${FILL_BASE_L + dl}%)`;
}

const SELECTED_FILL = '#c69a3b'; // brass-500

/**
 * Renders all country fills in a single Group so Skia can batch the draws.
 * Each path is parsed once and memoized; opacities animate in by region.
 */
export function CountryShapes({ features, selectedIsoA3, paintProgress }: Props) {
  const parsed = useMemo<ParsedFeature[]>(() => {
    // Group by region for staggered fade-in
    const byRegion = new Map<string, CountryShape[]>();
    for (const f of features) {
      const arr = byRegion.get(f.region) ?? [];
      arr.push(f);
      byRegion.set(f.region, arr);
    }
    const out: ParsedFeature[] = [];
    for (let r = 0; r < REGION_ORDER.length; r++) {
      const region = REGION_ORDER[r] as string;
      const regionFeatures = byRegion.get(region) ?? [];
      const regionStart = r / REGION_ORDER.length;
      const regionEnd = (r + 1) / REGION_ORDER.length;
      for (let i = 0; i < regionFeatures.length; i++) {
        const f = regionFeatures[i] as CountryShape;
        const path = Skia.Path.MakeFromSVGString(f.path);
        if (!path) continue;
        const within = regionFeatures.length > 0 ? i / regionFeatures.length : 0;
        const delay = regionStart + (regionEnd - regionStart) * within * 0.7;
        out.push({
          iso_a3: f.iso_a3,
          region: f.region,
          path,
          fill: colorFor(f.iso_a3),
          delay,
        });
      }
    }
    return out;
  }, [features]);

  return (
    <Group>
      {parsed.map((f) => (
        <SingleShape
          key={f.iso_a3}
          feature={f}
          isSelected={f.iso_a3 === selectedIsoA3}
          paintProgress={paintProgress}
        />
      ))}
    </Group>
  );
}

function SingleShape({
  feature,
  isSelected,
  paintProgress,
}: {
  feature: ParsedFeature;
  isSelected: boolean;
  paintProgress: SharedValue<number>;
}) {
  // Fade-in window of 0.12 around `delay`.
  const opacity = useDerivedValue(() => {
    const p = paintProgress.value;
    const start = feature.delay;
    const end = Math.min(start + 0.12, 1);
    if (p <= start) return 0;
    if (p >= end) return 1;
    return (p - start) / (end - start);
  });

  return (
    <Path
      path={feature.path}
      color={isSelected ? SELECTED_FILL : feature.fill}
      style="fill"
      opacity={opacity}
    />
  );
}
