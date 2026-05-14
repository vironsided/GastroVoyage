import { Pressable, Text, View, ActivityIndicator, type PressableProps } from 'react-native';
import { tap } from '../../lib/haptics';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';

interface ButtonProps extends Omit<PressableProps, 'children'> {
  label: string;
  variant?: Variant;
  loading?: boolean;
  fullWidth?: boolean;
}

const variants: Record<Variant, { container: string; text: string }> = {
  primary: {
    container: 'bg-navy-800 active:bg-navy-700',
    text: 'text-parchment-50 font-bodyBold',
  },
  secondary: {
    container: 'bg-parchment-200 border border-parchment-400 active:bg-parchment-300',
    text: 'text-navy-900 font-bodyBold',
  },
  ghost: {
    container: 'bg-transparent active:bg-parchment-200',
    text: 'text-navy-800 font-bodyMed',
  },
  danger: {
    container: 'bg-burgundy-500 active:bg-burgundy-700',
    text: 'text-parchment-50 font-bodyBold',
  },
};

export function Button({
  label,
  variant = 'primary',
  loading = false,
  fullWidth = false,
  disabled,
  onPress,
  ...rest
}: ButtonProps) {
  const v = variants[variant];
  const isDisabled = disabled || loading;

  return (
    <Pressable
      accessibilityRole="button"
      onPress={(e) => {
        tap();
        onPress?.(e);
      }}
      disabled={isDisabled}
      className={[
        'rounded-2xl px-5 py-3.5 items-center justify-center',
        v.container,
        fullWidth ? 'w-full' : '',
        isDisabled ? 'opacity-50' : '',
      ].join(' ')}
      {...rest}
    >
      <View className="flex-row items-center gap-2">
        {loading ? <ActivityIndicator size="small" color="#fbf7ee" /> : null}
        <Text className={['text-base', v.text].join(' ')}>{label}</Text>
      </View>
    </Pressable>
  );
}
