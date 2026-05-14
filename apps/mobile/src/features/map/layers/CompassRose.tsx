import { Circle, Group, Path, Skia } from '@shopify/react-native-skia';

interface Props {
  cx: number;
  cy: number;
  size?: number;
}

/**
 * Decorative compass rose in a corner of the canvas. Pure paths — looks like
 * an inked stamp on the paper.
 */
export function CompassRose({ cx, cy, size = 32 }: Props) {
  const ink = '#1c305db3';
  const r = size / 2;

  // Eight-point star: 4 long points (N/S/E/W) + 4 short points (NE/SE/SW/NW).
  const star = Skia.Path.Make();
  const long = r * 0.9;
  const short = r * 0.32;
  for (let i = 0; i < 8; i++) {
    const angle = (i * Math.PI) / 4 - Math.PI / 2; // start at North
    const isLong = i % 2 === 0;
    const len = isLong ? long : short;
    const x = cx + Math.cos(angle) * len;
    const y = cy + Math.sin(angle) * len;
    if (i === 0) star.moveTo(x, y);
    else star.lineTo(x, y);
  }
  star.close();

  return (
    <Group opacity={0.7}>
      <Circle cx={cx} cy={cy} r={r} color="transparent" style="stroke" strokeWidth={0.8}>
        <Path path={Skia.Path.Make().addCircle(cx, cy, r)} />
      </Circle>
      <Circle cx={cx} cy={cy} r={r} color={ink} style="stroke" strokeWidth={0.8} />
      <Circle cx={cx} cy={cy} r={r * 0.6} color={ink} style="stroke" strokeWidth={0.5} />
      <Path path={star} color={ink} style="fill" opacity={0.55} />
      <Path path={star} color={ink} style="stroke" strokeWidth={0.5} />
    </Group>
  );
}
