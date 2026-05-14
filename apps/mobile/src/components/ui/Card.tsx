import { View, type ViewProps } from 'react-native';

export function Card({ children, className = '', ...rest }: ViewProps & { className?: string }) {
  return (
    <View
      className={[
        'bg-parchment-50 border border-parchment-300 rounded-2xl p-5',
        'shadow-md shadow-navy-900/20',
        className,
      ].join(' ')}
      {...rest}
    >
      {children}
    </View>
  );
}
