import { useMemo } from 'react';
import { Canvas, Group } from '@shopify/react-native-skia';
import { useDerivedValue, type SharedValue } from 'react-native-reanimated';
import type { CountryShape } from '@gastrovoyage/shared';

import { CountryBorders } from './layers/CountryBorders';
import { CountryShapes } from './layers/CountryShapes';
import { PaperBackground } from './layers/PaperBackground';
import { CompassRose } from './layers/CompassRose';
import type { ViewportFit } from './utils/projection';

interface Props {
  width: number;
  height: number;
  features: CountryShape[];
  selectedIsoA3: string | null;
  fit: ViewportFit;
  matrix: SharedValue<{ translateX: number; translateY: number; scale: number }>;
  paintProgress: SharedValue<number>;
}

/**
 * The actual Skia canvas. All layers that don't need RN text (emoji flags)
 * live here. The Instax stamps and dots are rendered as RN views in
 * StampsOverlay so they can use the platform emoji font without us
 * having to ship Skia font assets.
 */
export function MapCanvas({
  width,
  height,
  features,
  selectedIsoA3,
  fit,
  matrix,
  paintProgress,
}: Props) {
  // Compose the world transform from the user matrix + the base fit transform.
  const worldTransform = useDerivedValue(() => {
    const m = matrix.value;
    return [
      { translateX: fit.baseTx + m.translateX },
      { translateY: fit.baseTy + m.translateY },
      { scale: fit.baseScale * m.scale },
    ];
  });

  // Centroid of the compass rose: top-right corner, padded.
  const compass = useMemo(() => ({ cx: width - 40, cy: 50 }), [width]);

  return (
    <Canvas style={{ width, height }}>
      <PaperBackground width={width} height={height} />
      <Group transform={worldTransform}>
        <CountryShapes
          features={features}
          selectedIsoA3={selectedIsoA3}
          paintProgress={paintProgress}
        />
        <CountryBorders features={features} />
      </Group>
      <CompassRose cx={compass.cx} cy={compass.cy} size={36} />
    </Canvas>
  );
}
