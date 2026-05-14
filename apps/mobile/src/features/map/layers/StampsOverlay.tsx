import { useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  type SharedValue,
} from 'react-native-reanimated';
import type { CountryShape } from '@gastrovoyage/shared';

import type { ViewportFit } from '../utils/projection';
import type { UserVisitSummary } from '../hooks/useMapData';

interface Props {
  features: CountryShape[];
  visitsByIsoA3: Map<string, UserVisitSummary>;
  fit: ViewportFit;
  matrix: SharedValue<{ translateX: number; translateY: number; scale: number }>;
}

function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

function isoA2ToFlagEmoji(iso2: string): string {
  if (!iso2 || iso2.length !== 2) return '🏳';
  const base = 0x1f1e6;
  const upper = iso2.toUpperCase();
  return (
    String.fromCodePoint(base + upper.charCodeAt(0) - 65) +
    String.fromCodePoint(base + upper.charCodeAt(1) - 65)
  );
}

/**
 * Renders unvisited "dots" and visited "Instax stamps" as absolutely-positioned
 * RN views above the Skia canvas. We use a single transform (matrix) shared
 * with the canvas so the overlay tracks pan/zoom 1:1 on the UI thread.
 *
 * Why RN views instead of Skia <Image>? Skia text/emoji rendering requires
 * loading font assets explicitly; RN's native <Text> renders emoji via the
 * platform font for free. The performance cost is minimal at 195 items.
 */
export function StampsOverlay({ features, visitsByIsoA3, fit, matrix }: Props) {
  // Only render an overlay for *visited* countries. Unvisited countries are
  // represented purely by the Skia paper-fill underneath, keeping the map
  // calm and uncluttered.
  const items = useMemo(() => {
    const out: Array<{
      iso_a3: string;
      iso_a2: string;
      baseX: number;
      baseY: number;
      tilt: number;
    }> = [];
    for (const f of features) {
      if (!visitsByIsoA3.has(f.iso_a3)) continue;
      const h = hash(f.iso_a3);
      const tilt = ((h % 200) - 100) / 10; // ±10°
      const baseX = f.cx * fit.baseScale + fit.baseTx;
      const baseY = f.cy * fit.baseScale + fit.baseTy;
      out.push({ iso_a3: f.iso_a3, iso_a2: f.iso_a2, baseX, baseY, tilt });
    }
    return out;
  }, [features, visitsByIsoA3, fit]);

  // IMPORTANT: we mimic Skia's matrix exactly here. Skia does
  //   translate(tx) -> scale(s) applied around the (0,0) origin of the canvas.
  // React Native's default transformOrigin is the *center* of the view, which
  // makes pinching drift the overlay away from the Skia layer. By pinning
  // transformOrigin to "0 0" we get identical math.
  const wrapperStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: matrix.value.translateX },
      { translateY: matrix.value.translateY },
      { scale: matrix.value.scale },
    ],
  }));

  return (
    <Animated.View
      pointerEvents="none"
      style={[StyleSheet.absoluteFill, styles.originTopLeft, wrapperStyle]}
    >
      {items.map((item) => (
        <View
          key={item.iso_a3}
          style={[
            styles.stamp,
            {
              left: item.baseX - STAMP_W / 2,
              top: item.baseY - STAMP_H / 2,
              transform: [{ rotate: `${item.tilt}deg` }],
            },
          ]}
        >
          <Text style={styles.stampFlag}>{isoA2ToFlagEmoji(item.iso_a2)}</Text>
        </View>
      ))}
    </Animated.View>
  );
}

const STAMP_W = 22;
const STAMP_H = 22;

const styles = StyleSheet.create({
  originTopLeft: {
    // Force RN to scale/translate around (0,0) instead of view center,
    // so the overlay matrix matches Skia's transform exactly.
    transformOrigin: '0% 0%',
  },
  // Round "ink stamp" look — much calmer than the white Instax card.
  stamp: {
    position: 'absolute',
    width: STAMP_W,
    height: STAMP_H,
    borderRadius: STAMP_W / 2,
    backgroundColor: 'rgba(251, 247, 238, 0.82)',
    borderColor: '#9e3a1d',
    borderWidth: 1.25,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#0d172b',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.18,
    shadowRadius: 1,
    elevation: 1,
  },
  stampFlag: {
    fontSize: 13,
    lineHeight: 14,
  },
});
