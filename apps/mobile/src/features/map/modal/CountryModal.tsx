import { useEffect } from 'react';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import type { CountryShape } from '@gastrovoyage/shared';

import { Button } from '../../../components/ui/Button';
import { supabase } from '../../../lib/supabase';
import { useAuth } from '../../../providers/AuthProvider';
import * as haptics from '../../../lib/haptics';
import type { UserVisitSummary } from '../hooks/useMapData';

interface Props {
  country: CountryShape | null;
  visit: UserVisitSummary | null;
  onClose: () => void;
}

function isoA2ToFlagEmoji(iso2: string): string {
  if (!iso2 || iso2.length !== 2) return '🏳';
  const base = 0x1f1e6;
  const upper = iso2.toUpperCase();
  return (
    String.fromCodePoint(base + upper.charCodeAt(0) - 65) +
    String.fromCodePoint(base + upper.charCodeAt(1) - 65)
  );
}

const SAMPLE_NOTES = [
  'A weeknight discovery — humble and unforgettable.',
  'Booked on a whim, stayed for hours.',
  'The kind of meal you write home about.',
  'Unassuming spot, transcendent flavor.',
  'Worth every minute of the queue outside.',
];

export function CountryModal({ country, visit, onClose }: Props) {
  const open = country !== null;
  const sheet = useSharedValue(0);
  const backdrop = useSharedValue(0);

  useEffect(() => {
    if (open) {
      sheet.value = withSpring(1, { damping: 18, stiffness: 140, mass: 0.8 });
      backdrop.value = withTiming(1, { duration: 220, easing: Easing.out(Easing.cubic) });
    } else {
      sheet.value = withTiming(0, { duration: 220 });
      backdrop.value = withTiming(0, { duration: 200 });
    }
  }, [open, sheet, backdrop]);

  const sheetStyle = useAnimatedStyle(() => ({
    transform: [
      {
        translateY: 480 * (1 - sheet.value),
      },
    ],
  }));
  const backdropStyle = useAnimatedStyle(() => ({ opacity: backdrop.value * 0.55 }));

  return (
    <Modal
      visible={open}
      transparent
      animationType="none"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <View style={StyleSheet.absoluteFill}>
        <Animated.View style={[StyleSheet.absoluteFill, styles.backdrop, backdropStyle]} />
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} />
        <Animated.View style={[styles.sheet, sheetStyle]}>
          {country ? (
            <CountryModalContents country={country} visit={visit} onClose={onClose} />
          ) : null}
        </Animated.View>
      </View>
    </Modal>
  );
}

function CountryModalContents({
  country,
  visit,
  onClose,
}: {
  country: CountryShape;
  visit: UserVisitSummary | null;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const { user } = useAuth();

  const markVisited = useMutation({
    mutationFn: async () => {
      if (!user) throw new Error('Not signed in');
      const { data: countryRow, error: lookupError } = await supabase
        .from('countries')
        .select('id')
        .eq('iso_a3', country.iso_a3)
        .single();
      if (lookupError || !countryRow) {
        throw new Error(lookupError?.message ?? 'Country not found in DB');
      }

      const rating = 3 + Math.floor(Math.random() * 3); // 3..5
      const noteIdx = Math.floor(Math.random() * SAMPLE_NOTES.length);
      const note = SAMPLE_NOTES[noteIdx] ?? 'A delicious moment.';
      const { error } = await supabase.from('visits').upsert(
        {
          user_id: user.id,
          country_id: countryRow.id,
          rating,
          notes: note,
          visited_on: new Date().toISOString().slice(0, 10),
        },
        { onConflict: 'user_id,country_id' },
      );
      if (error) throw error;
    },
    onSuccess: () => {
      haptics.success();
      queryClient.invalidateQueries({ queryKey: ['map', 'visits'] });
      onClose();
    },
    onError: () => {
      haptics.warning();
    },
  });

  const isVisited = visit !== null;

  return (
    <>
      <View style={styles.handle} />
      <View style={styles.header}>
        <Text style={styles.flag}>{isoA2ToFlagEmoji(country.iso_a2)}</Text>
        <View style={{ flex: 1 }}>
          <Text style={styles.name}>{country.name}</Text>
          <Text style={styles.region}>{country.region}</Text>
        </View>
      </View>

      {isVisited && visit ? (
        <View style={styles.statusVisited}>
          <Text style={styles.statusLabel}>VISITED</Text>
          <Text style={styles.visitDate}>on {visit.visitedOn}</Text>
          {visit.rating ? (
            <Text style={styles.rating}>{'★'.repeat(visit.rating)}</Text>
          ) : null}
          {visit.notes ? <Text style={styles.notes}>&ldquo;{visit.notes}&rdquo;</Text> : null}
          <View style={styles.actionRow}>
            <Button label="Replace photo" variant="secondary" disabled fullWidth />
          </View>
          <Text style={styles.devHint}>Camera arrives in Phase 5.</Text>
        </View>
      ) : (
        <View style={styles.statusUnvisited}>
          <Text style={styles.statusLabel}>NOT YET VISITED</Text>
          <Text style={styles.unvisitedHint}>
            Find a local restaurant serving this cuisine. Snap your Instax. Pin it to your map.
          </Text>
          <View style={styles.actionRow}>
            <Button label="Snap your Instax" disabled fullWidth />
          </View>
          <Text style={styles.devHint}>Camera arrives in Phase 5.</Text>
        </View>
      )}

      {__DEV__ ? (
        <View style={styles.devPanel}>
          <Text style={styles.devLabel}>Dev tools</Text>
          <Button
            label={
              markVisited.isPending
                ? 'Marking…'
                : isVisited
                  ? 'Reshuffle visit (dev)'
                  : 'Mark visited (dev)'
            }
            onPress={() => markVisited.mutate()}
            loading={markVisited.isPending}
            variant="secondary"
            fullWidth
          />
          {markVisited.isError ? (
            <Text style={styles.errorText}>
              {markVisited.error instanceof Error
                ? markVisited.error.message
                : 'Failed to mark visited'}
            </Text>
          ) : null}
        </View>
      ) : null}

      <Pressable onPress={onClose} style={styles.closeButton}>
        <Text style={styles.closeText}>Close</Text>
      </Pressable>
    </>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    backgroundColor: '#0d172b',
  },
  sheet: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: '#fbf7ee',
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    paddingHorizontal: 22,
    paddingTop: 10,
    paddingBottom: 32,
    shadowColor: '#0d172b',
    shadowOffset: { width: 0, height: -6 },
    shadowOpacity: 0.18,
    shadowRadius: 24,
    elevation: 24,
  },
  handle: {
    alignSelf: 'center',
    width: 44,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#cdb574',
    marginBottom: 12,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    marginBottom: 16,
  },
  flag: { fontSize: 40 },
  name: {
    fontSize: 26,
    color: '#0d172b',
    fontFamily: 'PlayfairDisplay_700Bold',
  },
  region: {
    fontSize: 13,
    color: '#574627',
    letterSpacing: 1,
    textTransform: 'uppercase',
    marginTop: 2,
  },
  statusVisited: {
    borderColor: '#cdb574',
    borderWidth: 1,
    borderRadius: 16,
    padding: 16,
    backgroundColor: '#f5ecd8',
  },
  statusUnvisited: {
    borderColor: '#cdb574',
    borderStyle: 'dashed',
    borderWidth: 1,
    borderRadius: 16,
    padding: 16,
  },
  statusLabel: {
    fontSize: 11,
    color: '#7b6232',
    letterSpacing: 2,
    fontFamily: 'Inter_500Medium',
  },
  visitDate: {
    color: '#0d172b',
    marginTop: 4,
    fontSize: 18,
  },
  rating: {
    color: '#c69a3b',
    fontSize: 22,
    marginTop: 6,
    letterSpacing: 2,
  },
  notes: {
    color: '#1c305d',
    fontStyle: 'italic',
    fontSize: 14,
    marginTop: 10,
  },
  unvisitedHint: {
    color: '#1c305d',
    marginTop: 6,
    fontSize: 14,
    lineHeight: 20,
  },
  actionRow: { marginTop: 14 },
  devHint: {
    color: '#7b6232',
    fontSize: 11,
    marginTop: 6,
    fontStyle: 'italic',
  },
  devPanel: {
    marginTop: 14,
    paddingTop: 14,
    borderTopWidth: 1,
    borderTopColor: '#e0cf9b',
  },
  devLabel: {
    color: '#7b6232',
    fontSize: 10,
    letterSpacing: 2,
    marginBottom: 8,
  },
  errorText: {
    color: '#9b2c2c',
    fontSize: 12,
    marginTop: 6,
  },
  closeButton: {
    marginTop: 14,
    alignSelf: 'center',
  },
  closeText: {
    color: '#1c305d',
    fontSize: 14,
    fontFamily: 'Inter_500Medium',
  },
});
