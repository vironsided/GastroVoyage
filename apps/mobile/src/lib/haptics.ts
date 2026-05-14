import { Platform } from 'react-native';
import * as Haptics from 'expo-haptics';

const isNative = Platform.OS === 'ios' || Platform.OS === 'android';

const safe = (fn: () => Promise<unknown>) => {
  if (!isNative) return;
  try {
    void fn();
  } catch {
    // Haptics may be unavailable in some envs (e.g. simulators); never crash UI.
  }
};

export const tap = () => safe(() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light));
export const success = () =>
  safe(() => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success));
export const warning = () =>
  safe(() => Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning));
export const heavy = () => safe(() => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy));
