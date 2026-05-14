import { useCallback } from 'react';
import type { CountryShape } from '@gastrovoyage/shared';

import { hitTestAtlas } from '../utils/hitTest';
import { fitAtlas, screenToAtlas } from '../utils/projection';

export interface UseCountryHitTestArgs {
  features: CountryShape[];
  atlasWidth: number;
  atlasHeight: number;
  viewportWidth: number;
  viewportHeight: number;
  /** Current scale (read via .value at tap time, not reactive). */
  getScale: () => number;
  getTx: () => number;
  getTy: () => number;
}

export function useCountryHitTest({
  features,
  atlasWidth,
  atlasHeight,
  viewportWidth,
  viewportHeight,
  getScale,
  getTx,
  getTy,
}: UseCountryHitTestArgs) {
  return useCallback(
    (screenX: number, screenY: number): CountryShape | null => {
      const fit = fitAtlas(atlasWidth, atlasHeight, viewportWidth, viewportHeight);
      const { x, y } = screenToAtlas(screenX, screenY, fit, getScale(), getTx(), getTy());
      // Scale-aware tolerance: zoomed-out -> tap is "fatter" in atlas space.
      const tolerance = 8 / getScale();
      return hitTestAtlas(features, x, y, tolerance);
    },
    [features, atlasWidth, atlasHeight, viewportWidth, viewportHeight, getScale, getTx, getTy],
  );
}
