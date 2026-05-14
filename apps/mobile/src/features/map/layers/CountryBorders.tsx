import { useMemo } from 'react';
import { Group, Path, Skia, type SkPath } from '@shopify/react-native-skia';
import type { CountryShape } from '@gastrovoyage/shared';

interface Props {
  features: CountryShape[];
  /** Stroke width in atlas units. We don't compensate for zoom — bolder at zoom. */
  strokeWidth?: number;
}

interface ParsedBorder {
  iso_a3: string;
  path: SkPath;
}

export function CountryBorders({ features, strokeWidth = 0.6 }: Props) {
  const parsed = useMemo<ParsedBorder[]>(
    () =>
      features
        .map((f) => {
          const path = Skia.Path.MakeFromSVGString(f.path);
          if (!path) return null;
          return { iso_a3: f.iso_a3, path };
        })
        .filter((x): x is ParsedBorder => x !== null),
    [features],
  );

  return (
    <Group color="#0d172bb3" style="stroke" strokeWidth={strokeWidth}>
      {parsed.map((f) => (
        <Path key={f.iso_a3} path={f.path} />
      ))}
    </Group>
  );
}
