import 'package:mobile/features/explore/africa_ingredients.dart';
import 'package:mobile/features/explore/americas_ingredients.dart';
import 'package:mobile/features/explore/asia_ingredients.dart';
import 'package:mobile/features/explore/europe_ingredients.dart';
import 'package:mobile/features/explore/middle_east_ingredients.dart';
import 'package:mobile/features/explore/oceania_ingredients.dart';

/// Resolves dish-specific ingredients by ISO code (ignores DB region label).
List<String>? ingredientsForCountry(String isoA2) {
  return kEuropeIngredients[isoA2] ??
      kAsiaIngredients[isoA2] ??
      kAfricaIngredients[isoA2] ??
      kAmericasIngredients[isoA2] ??
      kMiddleEastIngredients[isoA2] ??
      kOceaniaIngredients[isoA2];
}
