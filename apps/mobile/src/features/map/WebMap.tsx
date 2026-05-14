import { useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Svg, { Path, G, Rect } from 'react-native-svg';
import type { CountryShape } from '@gastrovoyage/shared';

import type { UserVisitSummary } from './hooks/useMapData';
import { fitAtlas } from './utils/projection';

interface Props {
  width: number;
  height: number;
  atlasWidth: number;
  atlasHeight: number;
  features: CountryShape[];
  visitsByIsoA3: Map<string, UserVisitSummary>;
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

const FILL_BASE_H = 41;
const FILL_BASE_S = 48;
const FILL_BASE_L = 82;

function colorFor(iso_a3: string): string {
  const h = hash(iso_a3);
  const dh = (h % 12) - 6;
  const dl = ((h >> 4) % 6) - 3;
  return `hsl(${FILL_BASE_H + dh}, ${FILL_BASE_S}%, ${FILL_BASE_L + dl}%)`;
}

const VISITED_FILL = '#c69a3b';

/**
 * Web-only static map. Renders the same pre-baked atlas through react-native-svg
 * so the project is fully testable from a desktop browser. Gestures are intentionally
 * omitted on web — Skia + Reanimated worklets are not portable to the DOM and the
 * use case here is screenshots / quick visual checks during development.
 */
export function WebMap({
  width,
  height,
  atlasWidth,
  atlasHeight,
  features,
  visitsByIsoA3,
}: Props) {
  const fit = useMemo(
    () => fitAtlas(atlasWidth, atlasHeight, width, height),
    [atlasWidth, atlasHeight, width, height],
  );

  return (
    <View style={[styles.root, { width, height }]}>
      <Svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}>
        <Rect x={0} y={0} width={width} height={height} fill="#fbf7ee" />
        <G
          transform={`translate(${fit.baseTx} ${fit.baseTy}) scale(${fit.baseScale})`}
        >
          {features.map((f) => {
            const visited = visitsByIsoA3.has(f.iso_a3);
            return (
              <Path
                key={f.iso_a3}
                d={f.path}
                fill={visited ? VISITED_FILL : colorFor(f.iso_a3)}
                stroke="#574627"
                strokeWidth={visited ? 0.6 : 0.3}
                strokeOpacity={0.55}
              />
            );
          })}
        </G>
      </Svg>

      {/* Stamps layer in DOM-positioned text so emoji render via system font. */}
      <View pointerEvents="none" style={StyleSheet.absoluteFill}>
        {features
          .filter((f) => visitsByIsoA3.has(f.iso_a3))
          .map((f) => {
            const x = f.cx * fit.baseScale + fit.baseTx;
            const y = f.cy * fit.baseScale + fit.baseTy;
            return (
              <View
                key={f.iso_a3}
                style={[
                  styles.stamp,
                  { left: x - STAMP_W / 2, top: y - STAMP_H / 2 },
                ]}
              >
                <Text style={styles.stampFlag}>
                  {isoA2ToFlagEmoji(f.iso_a2)}
                </Text>
              </View>
            );
          })}
      </View>
    </View>
  );
}

const STAMP_W = 22;
const STAMP_H = 22;

const styles = StyleSheet.create({
  root: {
    backgroundColor: '#fbf7ee',
  },
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
  },
  stampFlag: {
    fontSize: 13,
    lineHeight: 14,
  },
});
