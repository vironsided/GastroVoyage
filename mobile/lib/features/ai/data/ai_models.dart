/// Wire models for `/ai/*` and `/couples/wrapped`.
///
/// Every endpoint returns a structured payload (backend uses Claude's
/// `messages.parse()` with a Pydantic schema), so we deserialize each into
/// a typed Dart class — Mobile never has to render raw JSON.
///
/// All fields are null-safe: backend always returns strings, but Claude
/// can legitimately decide a field doesn't apply (e.g. no flag_emoji for
/// some countries, no restaurant text in a photo).

class AiDateNight {
  const AiDateNight({
    required this.countryName,
    required this.dishName,
    required this.headline,
    required this.whyTonight,
    required this.prepSteps,
    this.flagEmoji,
    this.cuisine,
  });

  final String countryName;
  final String dishName;
  final String headline;
  final String whyTonight;
  final List<String> prepSteps;
  final String? flagEmoji;
  final String? cuisine;

  factory AiDateNight.fromJson(Map<String, dynamic> j) => AiDateNight(
        countryName: (j['country_name'] as String?) ?? 'Somewhere',
        dishName: (j['dish_name'] as String?) ?? 'A bite together',
        headline: (j['headline'] as String?) ?? 'Cook something together tonight.',
        whyTonight: (j['why_tonight'] as String?) ?? '',
        prepSteps: ((j['prep_steps'] as List?) ?? const [])
            .whereType<String>()
            .toList(growable: false),
        flagEmoji: j['flag_emoji'] as String?,
        cuisine: j['cuisine'] as String?,
      );
}

class AiCuisineRecommendation {
  const AiCuisineRecommendation({
    required this.countryName,
    required this.reasoning,
    required this.signatureDish,
    this.flagEmoji,
    this.cuisine,
  });

  final String countryName;
  final String reasoning;
  final String signatureDish;
  final String? flagEmoji;
  final String? cuisine;

  factory AiCuisineRecommendation.fromJson(Map<String, dynamic> j) =>
      AiCuisineRecommendation(
        countryName: (j['country_name'] as String?) ?? '?',
        reasoning: (j['reasoning'] as String?) ?? '',
        signatureDish: (j['signature_dish'] as String?) ?? '',
        flagEmoji: j['flag_emoji'] as String?,
        cuisine: j['cuisine'] as String?,
      );
}

class AiCuisineRecommendations {
  const AiCuisineRecommendations({required this.items});
  final List<AiCuisineRecommendation> items;

  factory AiCuisineRecommendations.fromJson(Map<String, dynamic> j) =>
      AiCuisineRecommendations(
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AiCuisineRecommendation.fromJson)
            .toList(growable: false),
      );
}

/// What Claude vision extracted from an uploaded photo. Every field is
/// best-effort — Mobile pre-fills the form, but the user can override
/// anything before saving the visit.
class AiVisitPhotoSuggestion {
  const AiVisitPhotoSuggestion({
    required this.confidence,
    this.dishName,
    this.likelyCountryName,
    this.cuisine,
    this.restaurantVisibleText,
    this.suggestedDishRating,
    this.suggestedAtmosphereRating,
    this.suggestedNotes,
  });

  final String confidence; // 'low' | 'medium' | 'high'
  final String? dishName;
  final String? likelyCountryName;
  final String? cuisine;
  final String? restaurantVisibleText;
  final int? suggestedDishRating;
  final int? suggestedAtmosphereRating;
  final String? suggestedNotes;

  factory AiVisitPhotoSuggestion.fromJson(Map<String, dynamic> j) =>
      AiVisitPhotoSuggestion(
        confidence: (j['confidence'] as String?) ?? 'low',
        dishName: j['dish_name'] as String?,
        likelyCountryName: j['likely_country_name'] as String?,
        cuisine: j['cuisine'] as String?,
        restaurantVisibleText: j['restaurant_visible_text'] as String?,
        suggestedDishRating: (j['suggested_dish_rating'] as num?)?.toInt(),
        suggestedAtmosphereRating:
            (j['suggested_atmosphere_rating'] as num?)?.toInt(),
        suggestedNotes: j['suggested_notes'] as String?,
      );
}

class CoupleWrappedScene {
  const CoupleWrappedScene({
    required this.title,
    required this.body,
    this.statLabel,
    this.statValue,
  });

  final String title;
  final String body;
  final String? statLabel;
  final String? statValue;

  factory CoupleWrappedScene.fromJson(Map<String, dynamic> j) =>
      CoupleWrappedScene(
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        statLabel: j['stat_label'] as String?,
        statValue: j['stat_value'] as String?,
      );
}

class CoupleWrapped {
  const CoupleWrapped({
    required this.headline,
    required this.scenes,
    required this.closing,
  });

  final String headline;
  final List<CoupleWrappedScene> scenes;
  final String closing;

  factory CoupleWrapped.fromJson(Map<String, dynamic> j) => CoupleWrapped(
        headline: (j['headline'] as String?) ?? '',
        scenes: ((j['scenes'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CoupleWrappedScene.fromJson)
            .toList(growable: false),
        closing: (j['closing'] as String?) ?? '',
      );
}
