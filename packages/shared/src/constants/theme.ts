/**
 * GastroVoyage — design tokens.
 *
 * "Modern Vintage": deep navy, parchment cream, leather, brass.
 * Playfair Display for headings, Inter for UI. These are the single
 * source of truth — both the mobile app (NativeWind) and the admin
 * panel (Tailwind) consume them.
 */

export const palette = {
  // Primary navy — used for buttons, headings, dark surfaces.
  navy: {
    50:  '#eef1f7',
    100: '#d4dbe9',
    200: '#a9b7d3',
    300: '#7d92bd',
    400: '#536ea7',
    500: '#2f4d91',
    600: '#243d75',
    700: '#1c305d',
    800: '#152444',
    900: '#0d172b',
    950: '#070d1a',
  },

  // Parchment — backgrounds, card surfaces, "paper" feel.
  parchment: {
    50:  '#fbf7ee',
    100: '#f5ecd8',
    200: '#ecdfbe',
    300: '#e0cf9b',
    400: '#cdb574',
    500: '#b89952',
    600: '#9b7d3f',
    700: '#7b6232',
    800: '#574627',
    900: '#3a2f1c',
  },

  // Burgundy / leather accent — destructive states, partner badges.
  burgundy: {
    50:  '#fbecec',
    100: '#f4cccc',
    300: '#d77a7a',
    500: '#9b2c2c',
    700: '#6b1f1f',
    900: '#3a1010',
  },

  // Brass — premium accents, gold stars, badges.
  brass: {
    50:  '#fdf6e3',
    300: '#e8c66b',
    500: '#c69a3b',
    700: '#8e6b1e',
    900: '#4d3a10',
  },

  ink:   '#1c1a17', // near-black on parchment
  paper: '#fbf7ee',
  shadow:'rgba(13, 23, 43, 0.18)',
} as const;

export const semantic = {
  background:       palette.parchment[50],
  surface:          palette.parchment[100],
  surfaceElevated:  '#ffffff',
  border:           palette.parchment[300],
  textPrimary:      palette.navy[900],
  textMuted:        palette.navy[700],
  textOnDark:       palette.parchment[50],
  primary:          palette.navy[800],
  primaryHover:     palette.navy[700],
  accent:           palette.brass[500],
  danger:           palette.burgundy[500],
  success:          '#2f7d4f',
} as const;

export const typography = {
  fontFamilyHeading: 'PlayfairDisplay_700Bold',
  fontFamilyBody:    'Inter_400Regular',
  fontFamilyBodyMedium: 'Inter_500Medium',
  fontFamilyBodyBold:   'Inter_700Bold',

  sizes: {
    xs:   12,
    sm:   14,
    base: 16,
    lg:   18,
    xl:   22,
    '2xl': 28,
    '3xl': 36,
    '4xl': 48,
    '5xl': 64,
  },
} as const;

export const spacing = {
  px: 1,
  0:  0,
  1:  4,
  2:  8,
  3:  12,
  4:  16,
  5:  20,
  6:  24,
  8:  32,
  10: 40,
  12: 48,
  16: 64,
  20: 80,
} as const;

export const radius = {
  none: 0,
  sm:   4,
  base: 8,
  md:   12,
  lg:   16,
  xl:   20,
  '2xl': 28,
  full: 9999,
} as const;

export const shadows = {
  card: {
    shadowColor: palette.navy[900],
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 12,
    elevation: 4,
  },
  instax: {
    shadowColor: palette.navy[900],
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 6,
    elevation: 6,
  },
} as const;

export const motion = {
  fast:  150,
  base:  220,
  slow:  400,
  page:  500,
  curtain: 700,
} as const;

export const theme = {
  palette,
  semantic,
  typography,
  spacing,
  radius,
  shadows,
  motion,
} as const;

export type Theme = typeof theme;
