/**
 * Mobile Tailwind config — pulls tokens from @gastrovoyage/shared.
 * Keep this in sync conceptually with apps/admin/tailwind.config.ts.
 */
const { theme } = require('../../packages/shared/src/constants/theme');

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{ts,tsx}', './app/**/*.{ts,tsx}'],
  presets: [require('nativewind/preset')],
  theme: {
    extend: {
      colors: {
        navy: theme.palette.navy,
        parchment: theme.palette.parchment,
        burgundy: theme.palette.burgundy,
        brass: theme.palette.brass,
        ink: theme.palette.ink,
        paper: theme.palette.paper,
      },
      fontFamily: {
        heading: [theme.typography.fontFamilyHeading],
        body: [theme.typography.fontFamilyBody],
        bodyMed: [theme.typography.fontFamilyBodyMedium],
        bodyBold: [theme.typography.fontFamilyBodyBold],
      },
      borderRadius: {
        instax: '6px',
      },
    },
  },
  plugins: [],
};
