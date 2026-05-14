import { useMemo, useRef, useState } from 'react';
import {
  PanResponder,
  StyleSheet,
  Text,
  View,
  type GestureResponderEvent,
  type PanResponderGestureState,
} from 'react-native';
import Svg, {
  Circle,
  ClipPath,
  Defs,
  G,
  Path,
  RadialGradient,
  Rect,
  Stop,
} from 'react-native-svg';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { TOTAL_COUNTRIES, type CountryShape } from '@gastrovoyage/shared';

import { useMapData } from './hooks/useMapData';

interface Props {
  width: number;
  height: number;
}

export function WorldMap({ width, height }: Props) {
  const insets = useSafeAreaInsets();
  const { atlas, features, visitsByIsoA3 } = useMapData();

  const visitedCount = visitsByIsoA3.size;
  const pct = Math.min(100, Math.round((visitedCount / TOTAL_COUNTRIES) * 100));
  const progressPct = Math.max(2, pct);

  const globeSize = Math.min(width * 0.88, height * 0.56);
  const radius = globeSize / 2;
  const mapScale = globeSize / atlas.width * 1.72;
  const baseX = radius - (atlas.width * mapScale) / 2;
  const baseY = radius - (atlas.height * mapScale) / 2;

  const [rotationPx, setRotationPx] = useState(0);
  const startRotation = useRef(0);
  const rotateByPan = (_: GestureResponderEvent, g: PanResponderGestureState) => {
    setRotationPx(startRotation.current + g.dx * 0.95);
  };

  const pan = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => true,
        onMoveShouldSetPanResponder: () => true,
        onPanResponderGrant: () => {
          startRotation.current = rotationPx;
        },
        onPanResponderMove: rotateByPan,
        onPanResponderRelease: (_e, g) => {
          setRotationPx(startRotation.current + g.dx * 0.95);
        },
      }),
    [rotationPx],
  );

  const byIsoA3 = useMemo(() => {
    const m = new Map<string, CountryShape>();
    for (const f of features) m.set(f.iso_a3, f);
    return m;
  }, [features]);

  const foodNodes = useMemo(
    () => [
      { isoA3: 'AZE', emoji: '🥘', label: 'АЗЕРБАЙДЖАН:\nШАХ-ПЛОВ', size: 78 },
      { isoA3: 'ITA', emoji: '🍕', label: null, size: 58 },
      { isoA3: 'FRA', emoji: '🥐', label: null, size: 54 },
      { isoA3: 'MEX', emoji: '🌮', label: null, size: 56 },
    ],
    [],
  );

  const projectNode = (cx: number, cy: number) => {
    const atlasOffset = rotationPx / mapScale;
    let x = cx + atlasOffset;
    while (x < 0) x += atlas.width;
    while (x >= atlas.width) x -= atlas.width;
    const candidates = [x - atlas.width, x, x + atlas.width];
    const best = candidates.reduce((a, b) => {
      const ax = baseX + a * mapScale;
      const bx = baseX + b * mapScale;
      return Math.abs(ax - radius) < Math.abs(bx - radius) ? a : b;
    });
    return {
      x: baseX + best * mapScale,
      y: baseY + cy * mapScale,
    };
  };

  return (
    <View style={[styles.screen, { width, height }]}>
      <View style={[styles.header, { top: insets.top + 8 }]}>
        <Text style={styles.title}>GASTROVOYAGE: Карта Вкусов</Text>
        <View style={styles.counterRow}>
          <Text style={styles.counterMain}>{visitedCount}</Text>
          <Text style={styles.counterSub}>/{TOTAL_COUNTRIES} CUISINES</Text>
        </View>
        <View style={styles.progressGlowTrack}>
          <View style={[styles.progressGlowFill, { width: `${progressPct}%` }]} />
        </View>
      </View>

      <View style={[styles.globeWrap, { width: globeSize, height: globeSize }]} {...pan.panHandlers}>
        <Svg width={globeSize} height={globeSize} viewBox={`0 0 ${globeSize} ${globeSize}`}>
          <Defs>
            <RadialGradient id="ocean" cx="50%" cy="45%" r="62%">
              <Stop offset="0%" stopColor="#0f335f" />
              <Stop offset="68%" stopColor="#0a1f3c" />
              <Stop offset="100%" stopColor="#050d1c" />
            </RadialGradient>
            <ClipPath id="globeClip">
              <Circle cx={radius} cy={radius} r={radius - 4} />
            </ClipPath>
          </Defs>

          <Circle cx={radius} cy={radius} r={radius - 4} fill="url(#ocean)" />
          <Circle cx={radius} cy={radius} r={radius - 4} stroke="#34e7ff" strokeOpacity={0.28} strokeWidth={2} />

          <G clipPath="url(#globeClip)">
            <Rect x={0} y={0} width={globeSize} height={globeSize} fill="rgba(26,230,255,0.03)" />
            <G transform={`translate(${baseX + rotationPx} ${baseY}) scale(${mapScale})`}>
              {[-atlas.width, 0, atlas.width].map((shift) => (
                <G key={`world-${shift}`} transform={`translate(${shift} 0)`}>
                  {features.map((f) => {
                    const visited = visitsByIsoA3.has(f.iso_a3);
                    return (
                      <Path
                        key={`${shift}-${f.iso_a3}`}
                        d={f.path}
                        fill={visited ? '#f3a447' : '#3ed7ff'}
                        fillOpacity={visited ? 0.95 : 0.7}
                        stroke={visited ? '#ffd59a' : '#8beaff'}
                        strokeOpacity={0.55}
                        strokeWidth={0.9}
                      />
                    );
                  })}
                </G>
              ))}
            </G>
          </G>
        </Svg>

        <Text style={styles.pacific}>ТИХИЙ{'\n'}ОКЕАН</Text>

        {foodNodes.map((n) => {
          const f = byIsoA3.get(n.isoA3);
          if (!f) return null;
          const p = projectNode(f.cx, f.cy);
          return (
            <View
              key={n.isoA3}
              style={[
                styles.foodNode,
                {
                  width: n.size,
                  height: n.size * 0.64,
                  left: p.x - n.size / 2,
                  top: p.y - n.size / 2,
                },
              ]}
            >
              <Text style={styles.foodEmoji}>{n.emoji}</Text>
              {n.label ? <Text style={styles.foodLabel}>{n.label}</Text> : null}
            </View>
          );
        })}
      </View>

      <View style={styles.rotateHint}>
        <Text style={styles.rotateArrow}>←</Text>
        <Text style={styles.rotateHand}>☝</Text>
        <Text style={styles.rotateArrow}>→</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    backgroundColor: '#040c1a',
    alignItems: 'center',
    justifyContent: 'flex-start',
  },
  header: {
    position: 'absolute',
    left: 18,
    right: 18,
    zIndex: 20,
  },
  title: {
    fontSize: 35,
    color: '#8ef4ff',
    fontFamily: 'PlayfairDisplay_700Bold',
    textShadowColor: 'rgba(75, 235, 255, 0.75)',
    textShadowOffset: { width: 0, height: 0 },
    textShadowRadius: 18,
    marginBottom: 7,
  },
  counterRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    marginBottom: 8,
  },
  counterMain: {
    color: '#d5f9ff',
    fontSize: 31,
    fontFamily: 'PlayfairDisplay_700Bold',
    marginRight: 4,
  },
  counterSub: {
    color: '#7e9cb3',
    fontSize: 20,
    letterSpacing: 2,
    fontFamily: 'Inter_500Medium',
  },
  progressGlowTrack: {
    height: 8,
    borderRadius: 6,
    backgroundColor: 'rgba(40, 90, 140, 0.55)',
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(60, 190, 255, 0.28)',
  },
  progressGlowFill: {
    height: '100%',
    borderRadius: 6,
    backgroundColor: '#59e6ff',
    shadowColor: '#59e6ff',
    shadowOpacity: 0.9,
    shadowRadius: 8,
    elevation: 5,
  },
  globeWrap: {
    marginTop: 170,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: 'rgba(95, 217, 255, 0.28)',
    shadowColor: '#36dfff',
    shadowOpacity: 0.38,
    shadowRadius: 22,
    elevation: 8,
  },
  pacific: {
    position: 'absolute',
    right: '22%',
    top: '63%',
    color: 'rgba(126, 198, 225, 0.63)',
    fontSize: 20,
    letterSpacing: 1.2,
    lineHeight: 22,
    fontFamily: 'Inter_500Medium',
    textAlign: 'center',
  },
  foodNode: {
    position: 'absolute',
    borderRadius: 999,
    backgroundColor: 'rgba(12, 23, 42, 0.72)',
    borderWidth: 1.2,
    borderColor: 'rgba(124, 228, 255, 0.4)',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.36,
    shadowRadius: 8,
    elevation: 7,
    overflow: 'visible',
  },
  foodEmoji: {
    fontSize: 31,
  },
  foodLabel: {
    position: 'absolute',
    top: -50,
    width: 160,
    color: '#d7f8ff',
    textAlign: 'center',
    fontSize: 17,
    lineHeight: 20,
    fontFamily: 'Inter_700Bold',
    textShadowColor: 'rgba(0,0,0,0.9)',
    textShadowOffset: { width: 0, height: 2 },
    textShadowRadius: 4,
  },
  rotateHint: {
    marginTop: 18,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  rotateHand: {
    fontSize: 30,
    color: '#e4f7ff',
  },
  rotateArrow: {
    fontSize: 27,
    color: '#9cc8de',
    fontFamily: 'Inter_700Bold',
  },
});
