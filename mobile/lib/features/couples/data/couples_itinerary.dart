/// Curated data for the "Weekly Couples' Culinary Journey".
///
/// A chronological, gamified roadmap: each week is one cuisine with a
/// couple-framed narrative, signature dishes, and a mood tag. The recommended
/// real Baku restaurant for a week is matched at runtime from
/// `kBakuRestaurants` by `cuisine` — see [restaurantsForWeek].
///
/// Every `cuisine` value below MUST match a `BakuRestaurant.cuisine` so a real
/// venue can be paired with the week.
library;

import 'package:mobile/features/baku/data/baku_restaurant.dart';

/// One stop on the couples' culinary roadmap.
class ItineraryWeek {
  const ItineraryWeek({
    required this.weekNumber,
    required this.cuisine,
    required this.flag,
    required this.title,
    required this.narrative,
    required this.signatureDishes,
    required this.mood,
  });

  /// 1-based position in the journey.
  final int weekNumber;

  /// Must match a `BakuRestaurant.cuisine` value.
  final String cuisine;

  /// Country flag emoji for the cuisine.
  final String flag;

  /// Short evocative week title.
  final String title;

  /// 2-4 sentences, couple-framed — why experience this together.
  final String narrative;

  /// 2-3 signature dishes to order and share.
  final List<String> signatureDishes;

  /// A short tag describing the evening's feel.
  final String mood;
}

/// The curated 8-week couples' journey across Baku, in order.
///
/// The progression is deliberate: it opens loud, social and playful, eases
/// into clean coastal calm, builds through cosy and ceremonial evenings, and
/// closes on the most romantic, candle-lit cuisine of all.
const List<ItineraryWeek> kCouplesJourney = <ItineraryWeek>[
  ItineraryWeek(
    weekNumber: 1,
    cuisine: 'Spanish',
    flag: '🇪🇸',
    title: 'The Tapas Icebreaker',
    narrative:
        'Begin loud and unhurried. Spanish tapas are built for two pairs of '
        'hands reaching across the same little plates, so there is never an '
        'awkward silence — only the next thing to try. Order more than you '
        'think you need, let the table fill up, and treat the first week as '
        'permission to be playful together.',
    signatureDishes: ['Patatas bravas', 'Gambas al ajillo', 'Jamón ibérico'],
    mood: 'Playful & shared',
  ),
  ItineraryWeek(
    weekNumber: 2,
    cuisine: 'Greek',
    flag: '🇬🇷',
    title: 'A Coastal Exhale',
    narrative:
        'After the buzz of week one, slow down by the imagined sea. Greek '
        'cooking is bright, clean and generous — grilled fish, lemon, herbs '
        'and olive oil — and the tavern vibe invites long, easy conversation. '
        'Split a whole fish down the middle; learning to share the good bits '
        'fairly is its own small ritual.',
    signatureDishes: ['Grilled octopus', 'Greek salad', 'Lemon-herb sea bass'],
    mood: 'Calm & coastal',
  ),
  ItineraryWeek(
    weekNumber: 3,
    cuisine: 'Italian',
    flag: '🇮🇹',
    title: 'The Comfort Classic',
    narrative:
        'Week three is the warm hug of the journey. Italian food asks nothing '
        'of you but to relax — a shared bowl of pasta, a blistered pizza torn '
        'in half, a candle between you. This is the night to talk about '
        'nothing in particular and realise that is exactly the point.',
    signatureDishes: ['Tagliatelle al ragù', 'Margherita pizza', 'Tiramisù'],
    mood: 'Cosy & familiar',
  ),
  ItineraryWeek(
    weekNumber: 4,
    cuisine: 'Japanese',
    flag: '🇯🇵',
    title: 'Quiet Precision',
    narrative:
        'Now bring some focus. Japanese dining rewards attention — the order '
        'of the courses, the temperature of the sake, the small ceremony of '
        'each piece of sushi. Sit close at the bar, watch the chef work, and '
        'practise being present with each other instead of distracted.',
    signatureDishes: ['Omakase nigiri', 'Miso black cod', 'Edamame'],
    mood: 'Mindful & intimate',
  ),
  ItineraryWeek(
    weekNumber: 5,
    cuisine: 'Georgian',
    flag: '🇬🇪',
    title: 'The Feast & The Toast',
    narrative:
        'Halfway in, throw a small feast. Georgian supra culture is all about '
        'abundance and heartfelt toasts — the tamada raises a glass to love, '
        'and so should you. Break open a cheese-filled khachapuri together, '
        'make a toast to how far you have come, and mean it.',
    signatureDishes: ['Adjarian khachapuri', 'Khinkali dumplings', 'Lobio'],
    mood: 'Generous & celebratory',
  ),
  ItineraryWeek(
    weekNumber: 6,
    cuisine: 'Lebanese',
    flag: '🇱🇧',
    title: 'The Long Table',
    narrative:
        'Lebanese mezze is a marathon, not a sprint — dozens of small dishes '
        'arriving slowly, meant to be lingered over. Let the evening stretch. '
        'Tear warm bread, scoop, taste, pass the plate, and use the unhurried '
        'rhythm to ask each other the bigger questions.',
    signatureDishes: ['Hummus & warm pita', 'Tabbouleh', 'Mixed grill mezze'],
    mood: 'Unhurried & warm',
  ),
  ItineraryWeek(
    weekNumber: 7,
    cuisine: 'Turkish',
    flag: '🇹🇷',
    title: 'Smoke, Spice & Sweetness',
    narrative:
        'Week seven turns up the warmth again. Turkish cooking is smoky '
        'kebabs, vivid mezze and a finish so sweet it lingers. Share a sizzling '
        'platter, then split a single piece of baklava and a strong tea — the '
        'kind of cosy, slightly indulgent night that feels like a reward.',
    signatureDishes: ['Adana kebab', 'Şakşuka', 'Baklava with tea'],
    mood: 'Warm & indulgent',
  ),
  ItineraryWeek(
    weekNumber: 8,
    cuisine: 'French',
    flag: '🇫🇷',
    title: 'The Grand Finale',
    narrative:
        'You have arrived. French dining is the most romantic chapter for a '
        'reason — soft light, an unhurried multi-course rhythm, a shared '
        'dessert and a toast to everything tasted along the way. Dress up a '
        'little. This last week is meant to feel like an occasion, because it '
        'is one.',
    signatureDishes: ['French onion soup', 'Steak au poivre', 'Crème brûlée'],
    mood: 'Romantic & memorable',
  ),
];

/// Total weeks in the curated journey.
int get kCouplesJourneyLength => kCouplesJourney.length;

/// Real Baku restaurants whose cuisine matches [week]'s cuisine.
///
/// Returns every match (callers typically take the first as the headline
/// recommendation); empty only if no Baku venue serves that cuisine.
List<BakuRestaurant> restaurantsForWeek(ItineraryWeek week) {
  return kBakuRestaurants
      .where((r) => r.cuisine == week.cuisine)
      .toList(growable: false);
}

/// The single headline Baku restaurant recommendation for [week], or null if
/// no matching venue exists in the catalog.
BakuRestaurant? restaurantForWeek(ItineraryWeek week) {
  final matches = restaurantsForWeek(week);
  return matches.isEmpty ? null : matches.first;
}
