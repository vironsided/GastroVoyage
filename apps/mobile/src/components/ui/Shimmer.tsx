import { useEffect } from 'react';
import { View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
  Easing,
} from 'react-native-reanimated';

interface ShimmerProps {
  width?: number | `${number}%`;
  height?: number;
  rounded?: number;
}

export function Shimmer({ width = '100%', height = 16, rounded = 8 }: ShimmerProps) {
  const progress = useSharedValue(0);

  useEffect(() => {
    progress.value = withRepeat(
      withTiming(1, { duration: 1200, easing: Easing.inOut(Easing.ease) }),
      -1,
      true,
    );
  }, [progress]);

  const animated = useAnimatedStyle(() => ({
    opacity: 0.35 + progress.value * 0.5,
  }));

  return (
    <View
      style={{ width: width as number, height, borderRadius: rounded, overflow: 'hidden' }}
      className="bg-parchment-200"
    >
      <Animated.View
        style={[{ flex: 1, backgroundColor: '#e0cf9b' }, animated]}
      />
    </View>
  );
}
