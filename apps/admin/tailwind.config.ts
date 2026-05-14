import type { Config } from 'tailwindcss';
import { theme as gv } from '../../packages/shared/src/constants/theme';

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        navy: gv.palette.navy,
        parchment: gv.palette.parchment,
        burgundy: gv.palette.burgundy,
        brass: gv.palette.brass,
        ink: gv.palette.ink,
        paper: gv.palette.paper,
      },
      fontFamily: {
        heading: ['"Playfair Display"', 'serif'],
        body: ['Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
};

export default config;
