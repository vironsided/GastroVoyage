import { Fill, LinearGradient, Rect, vec } from '@shopify/react-native-skia';

interface Props {
  width: number;
  height: number;
}

/**
 * Parchment paper backdrop. Two layers:
 *   1. Solid parchment-50 base.
 *   2. A diagonal sepia gradient for an aged-paper feel.
 *
 * (Noise/grain texture intentionally omitted to avoid shipping a binary
 * asset in this phase. A subtle vignette via gradient does most of the work.)
 */
export function PaperBackground({ width, height }: Props) {
  return (
    <>
      <Fill color="#fbf7ee" />
      <Rect x={0} y={0} width={width} height={height}>
        <LinearGradient
          start={vec(0, 0)}
          end={vec(width, height)}
          colors={['rgba(184, 153, 82, 0)', 'rgba(184, 153, 82, 0.18)']}
        />
      </Rect>
    </>
  );
}
