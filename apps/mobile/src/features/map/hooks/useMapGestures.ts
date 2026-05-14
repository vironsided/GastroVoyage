import { useCallback } from 'react';
import { Gesture } from 'react-native-gesture-handler';
import {
  useSharedValue,
  useDerivedValue,
  withSpring,
  withTiming,
  runOnJS,
  type SharedValue,
} from 'react-native-reanimated';

export interface MapGestureState {
  /** Cumulative user-controlled scale (multiplier on top of the base fit). */
  scale: SharedValue<number>;
  /** Cumulative user pan in screen pixels. */
  tx: SharedValue<number>;
  ty: SharedValue<number>;
  /** A Reanimated transform array consumable by Skia's <Group transform>. */
  matrix: SharedValue<{ translateX: number; translateY: number; scale: number }>;
  /** Composite gesture to attach to a GestureDetector wrapping the canvas. */
  composedGesture: ReturnType<typeof Gesture.Race>;
  /** Reset to initial fit. */
  resetView: () => void;
}

const MIN_SCALE = 0.9;
const MAX_SCALE = 6;
const DOUBLE_TAP_TARGET = 2.5;
const SPRING = { damping: 18, stiffness: 110, mass: 0.6 };

export interface UseMapGesturesArgs {
  /** Optional tap handler — runs on JS thread, given screen coords. */
  onTap?: (x: number, y: number) => void;
  /** Viewport size for clamping pan. */
  viewportWidth: number;
  viewportHeight: number;
}

export function useMapGestures({
  onTap,
  viewportWidth,
  viewportHeight,
}: UseMapGesturesArgs): MapGestureState {
  const scale = useSharedValue(1);
  const savedScale = useSharedValue(1);
  const tx = useSharedValue(0);
  const ty = useSharedValue(0);
  const savedTx = useSharedValue(0);
  const savedTy = useSharedValue(0);
  const focalX = useSharedValue(0);
  const focalY = useSharedValue(0);

  const matrix = useDerivedValue(() => ({
    translateX: tx.value,
    translateY: ty.value,
    scale: scale.value,
  }));

  /** Clamp pan so the map doesn't fly off-screen at high zooms. */
  const clamp = (value: number, min: number, max: number) => {
    'worklet';
    if (value < min) return min;
    if (value > max) return max;
    return value;
  };

  const pinch = Gesture.Pinch()
    .onStart((e) => {
      savedScale.value = scale.value;
      focalX.value = e.focalX;
      focalY.value = e.focalY;
    })
    .onUpdate((e) => {
      const next = clamp(savedScale.value * e.scale, MIN_SCALE, MAX_SCALE);
      // Adjust translation so the pinch is centered on the focal point.
      const ratio = next / scale.value;
      tx.value = focalX.value - ratio * (focalX.value - tx.value);
      ty.value = focalY.value - ratio * (focalY.value - ty.value);
      scale.value = next;
    })
    .onEnd(() => {
      // Spring back into bounds if needed.
      const bounded = clamp(scale.value, 1, MAX_SCALE);
      if (bounded !== scale.value) {
        scale.value = withSpring(bounded, SPRING);
      }
    });

  const pan = Gesture.Pan()
    .minDistance(4)
    .onStart(() => {
      savedTx.value = tx.value;
      savedTy.value = ty.value;
    })
    .onUpdate((e) => {
      tx.value = savedTx.value + e.translationX;
      ty.value = savedTy.value + e.translationY;
    })
    .onEnd(() => {
      // Rubber-band back into view if dragged too far.
      const limitX = viewportWidth * 0.6 * scale.value;
      const limitY = viewportHeight * 0.6 * scale.value;
      const targetX = clamp(tx.value, -limitX, limitX);
      const targetY = clamp(ty.value, -limitY, limitY);
      if (targetX !== tx.value) tx.value = withSpring(targetX, SPRING);
      if (targetY !== ty.value) ty.value = withSpring(targetY, SPRING);
    });

  const doubleTap = Gesture.Tap()
    .numberOfTaps(2)
    .maxDelay(280)
    .onEnd((e) => {
      const target = scale.value > 1.5 ? 1 : DOUBLE_TAP_TARGET;
      const ratio = target / scale.value;
      tx.value = withTiming(e.x - ratio * (e.x - tx.value), { duration: 280 });
      ty.value = withTiming(e.y - ratio * (e.y - ty.value), { duration: 280 });
      scale.value = withTiming(target, { duration: 280 });
    });

  const tap = Gesture.Tap()
    .numberOfTaps(1)
    .maxDistance(8)
    .onEnd((e, success) => {
      if (!success) return;
      if (onTap) runOnJS(onTap)(e.x, e.y);
    })
    .requireExternalGestureToFail(doubleTap);

  const composedGesture = Gesture.Race(
    Gesture.Simultaneous(pinch, pan),
    doubleTap,
    tap,
  );

  const resetView = useCallback(() => {
    scale.value = withSpring(1, SPRING);
    tx.value = withSpring(0, SPRING);
    ty.value = withSpring(0, SPRING);
  }, [scale, tx, ty]);

  return {
    scale,
    tx,
    ty,
    matrix,
    composedGesture,
    resetView,
  };
}
