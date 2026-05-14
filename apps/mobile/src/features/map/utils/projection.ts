/**
 * Map projection math for the GastroVoyage world map.
 *
 * The pre-baked atlas stores all coordinates in a virtual projection space
 * (currently 1000 x 500 — see tools/generate-country-shapes.mjs). At runtime
 * we fit that virtual canvas into the user's screen, applying their
 * pinch/pan transforms on top.
 */

export interface ViewportFit {
  /** Multiplier from virtual atlas pixels -> screen pixels. */
  baseScale: number;
  /** Screen-space offsets when scale = 1. Centers the atlas in the viewport. */
  baseTx: number;
  baseTy: number;
  /** Resulting on-screen size of the atlas at scale=1. */
  fittedWidth: number;
  fittedHeight: number;
}

/**
 * Compute the "fit" of the atlas into a viewport such that the entire world
 * is visible without cropping (letterboxed). User-controlled scale & pan are
 * applied on top of this baseline.
 */
export function fitAtlas(
  atlasWidth: number,
  atlasHeight: number,
  viewportWidth: number,
  viewportHeight: number,
): ViewportFit {
  const sx = viewportWidth / atlasWidth;
  const sy = viewportHeight / atlasHeight;
  const baseScale = Math.min(sx, sy);

  const fittedWidth = atlasWidth * baseScale;
  const fittedHeight = atlasHeight * baseScale;

  return {
    baseScale,
    baseTx: (viewportWidth - fittedWidth) / 2,
    baseTy: (viewportHeight - fittedHeight) / 2,
    fittedWidth,
    fittedHeight,
  };
}

/**
 * Given a tap location in screen coordinates and the current transform state,
 * return the corresponding atlas-space coordinate.
 */
export function screenToAtlas(
  screenX: number,
  screenY: number,
  fit: ViewportFit,
  userScale: number,
  userTx: number,
  userTy: number,
): { x: number; y: number } {
  const effScale = fit.baseScale * userScale;
  const offsetX = fit.baseTx + userTx;
  const offsetY = fit.baseTy + userTy;
  return {
    x: (screenX - offsetX) / effScale,
    y: (screenY - offsetY) / effScale,
  };
}
