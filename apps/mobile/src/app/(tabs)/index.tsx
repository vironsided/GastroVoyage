import { useState } from 'react';
import { View, type LayoutChangeEvent } from 'react-native';

import { WorldMap } from '../../features/map/WorldMap';

export default function MapScreen() {
  const [size, setSize] = useState<{ width: number; height: number } | null>(null);

  const onLayout = (e: LayoutChangeEvent) => {
    const { width, height } = e.nativeEvent.layout;
    if (!size || size.width !== width || size.height !== height) {
      setSize({ width, height });
    }
  };

  return (
    <View className="flex-1 bg-parchment-50" onLayout={onLayout}>
      {size ? <WorldMap width={size.width} height={size.height} /> : null}
    </View>
  );
}
