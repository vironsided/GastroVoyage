import 'package:mobile/features/explore/country_dishes.dart';
import 'package:mobile/features/explore/country_ingredients.dart';

/// Rich dish profile for Explore detail (TasteAtlas-style layout).
class DishCatalogEntry {
  const DishCatalogEntry({
    required this.dish,
    required this.imageUrl,
    required this.categories,
    required this.description,
    required this.ingredients,
    this.alternateNames = const [],
    this.rating = 4.4,
  });

  final String dish;
  final String imageUrl;
  final List<String> categories;
  final String description;
  final List<String> ingredients;
  final List<String> alternateNames;
  final double rating;
}

// ── Curated deep profiles (original summaries, structure inspired by food atlases) ──

final Map<String, DishCatalogEntry> _rich = {
  'PL': DishCatalogEntry(
    dish: 'Pierogi',
    imageUrl: kCountryDishes['PL']!.imageUrl,
    categories: ['DUMPLINGS', 'STREET FOOD', 'COMFORT FOOD'],
    alternateNames: ['Pirogi', 'Pyry', 'Varenyky', 'Pieróg'],
    ingredients: [
      'Flour',
      'Eggs',
      'Twaróg cheese',
      'Potatoes',
      'Onion',
      'Sauerkraut',
      'Mushrooms',
      'Butter',
    ],
    rating: 4.5,
    description:
        'Pierogi are crescent-shaped dumplings that sit at the heart of Polish home cooking. '
        'The name comes from an old Slavic word for “feast,” and fillings range from savory '
        'potato and cheese to sauerkraut, mushroom, and sweet fruit for holidays.\n\n'
        'In Kraków and Warsaw you will find them boiled and pan-fried with onions, served '
        'in milk bars and at family tables on Christmas Eve. Each region claims its own '
        'version — leniwe (lazy pierogi), pierogi ruskie, and sweet versions with blueberries '
        'or plums.\n\n'
        'Making pierogi is a social ritual: dough rolled thin, filled, pinched shut, '
        'then boiled until they float. A final sizzle in butter turns them golden and aromatic.',
  ),
  'IT': DishCatalogEntry(
    dish: 'Spaghetti Carbonara',
    imageUrl: kCountryDishes['IT']!.imageUrl,
    categories: ['PASTA', 'ROMAN', 'CLASSIC'],
    ingredients: ['Spaghetti', 'Guanciale', 'Eggs', 'Pecorino Romano', 'Black pepper'],
    rating: 4.6,
    description:
        'Carbonara is Rome’s iconic pasta — silky, peppery, and built from just a handful '
        'of ingredients. Guanciale renders its fat into the pan; eggs and Pecorino emulsify '
        'into a creamy sauce without cream.\n\n'
        'The dish likely evolved in the mid-twentieth century among charcoal workers (carbonai) '
        'in the Apennines, though Romans fiercely debate every detail. Served al dente, '
        'it must be eaten immediately while the sauce still clings to each strand.',
  ),
  'JP': DishCatalogEntry(
    dish: 'Japanese Ramen',
    imageUrl: kCountryDishes['JP']!.imageUrl,
    categories: ['NOODLES', 'SOUP', 'STREET FOOD'],
    ingredients: ['Wheat noodles', 'Pork broth', 'Soy sauce', 'Chashu', 'Egg', 'Nori', 'Scallion'],
    rating: 4.7,
    description:
        'Ramen is Japan’s beloved noodle soup — regional styles from Sapporo miso to Hakata tonkotsu '
        'and Tokyo shoyu. Each bowl layers broth, tare seasoning, noodles with precise bite, '
        'and toppings that tell a local story.\n\n'
        'Late-night shops and station counters serve it fast and hot; craft ramen shops '
        'treat broth simmering as a multi-day art form.',
  ),
  'DZ': DishCatalogEntry(
    dish: 'Algerian Kefta',
    imageUrl: kCountryDishes['DZ']!.imageUrl,
    categories: ['GRILLED', 'SPICED', 'NORTH AFRICA'],
    ingredients: ['Lamb', 'Beef', 'Cumin', 'Paprika', 'Parsley', 'Onion', 'Garlic'],
    rating: 4.3,
    description:
        'Kefta in Algeria means seasoned ground meat shaped into balls or skewers, '
        'grilled over charcoal and served with bread, harissa, and salad. Cumin, coriander, '
        'and fresh herbs define the spice profile.\n\n'
        'Street grills in Algiers and Oran perfume the evening air; at home, families '
        'shape kefta by hand and serve it with couscous or as a sandwich filling.',
  ),
  'MT': DishCatalogEntry(
    dish: 'Seafood Fideua',
    imageUrl: kCountryDishes['MT']!.imageUrl,
    categories: ['SEAFOOD', 'PASTA', 'MEDITERRANEAN'],
    ingredients: ['Thin noodles', 'Shrimp', 'Mussels', 'Fish stock', 'Saffron', 'Garlic'],
    rating: 4.4,
    description:
        'Fideuà is a Mediterranean noodle paella — thin pasta toasted in olive oil, '
        'then simmered in rich seafood stock until the bottom crisps. Malta’s island '
        'kitchen blends Sicilian and North African influences.\n\n'
        'Harbor towns serve it with the catch of the day; saffron and aioli are common accents.',
  ),
  'MX': DishCatalogEntry(
    dish: 'Fish Tacos',
    imageUrl: kCountryDishes['MX']!.imageUrl,
    categories: ['TACOS', 'STEW', 'STREET FOOD'],
    ingredients: ['Goat', 'Chiles', 'Corn tortillas', 'Onion', 'Cilantro', 'Lime'],
    rating: 4.6,
    description:
        'Birria began in Jalisco as a celebratory goat stew, deeply spiced with dried chiles. '
        'Today it is famous as tacos dipped in consommé and griddled until crisp.\n\n'
        'The broth is rich, slightly tangy, and meant for sipping alongside every bite.',
  ),
};

DishCatalogEntry catalogFor({
  required String isoA2,
  required String region,
  required String countryName,
}) {
  final base = dishFor(isoA2: isoA2, region: region);
  final rich = _rich[isoA2];
  if (rich != null) return rich;

  final categories = _categoriesForRegion(region);
  final countryIngredients = ingredientsForCountry(isoA2);

  return DishCatalogEntry(
    dish: base.dish,
    imageUrl: base.imageUrl,
    categories: categories,
    ingredients: countryIngredients ?? _defaultIngredients(region),
    rating: 4.3,
    description:
        '${base.dish} is one of the most recognizable dishes associated with $countryName. '
        'Home cooks and street vendors alike guard family recipes passed through generations.\n\n'
        'In $region, flavors reflect local agriculture, spice trade routes, and celebration '
        'foods tied to holidays and gatherings. Travelers often discover it in markets, '
        'small restaurants, and home kitchens — the most authentic version rarely sits on '
        'a tourist menu.\n\n'
        'Try it fresh, share the story behind your first bite, and log your visit in '
        'GastroVoyage to keep the memory on your culinary passport.',
  );
}

List<String> _categoriesForRegion(String region) {
  switch (region) {
    case 'Asia':
      return ['TRADITIONAL', 'COMFORT FOOD', 'LOCAL FAVORITE'];
    case 'Europe':
      return ['CLASSIC', 'HERITAGE', 'COMFORT FOOD'];
    case 'Africa':
      return ['TRADITIONAL', 'SPICED', 'REGIONAL'];
    case 'Americas':
      return ['STREET FOOD', 'COMFORT FOOD', 'CLASSIC'];
    case 'Oceania':
      return ['SEAFOOD', 'GRILLED', 'LOCAL FAVORITE'];
    case 'Middle East':
      return ['TRADITIONAL', 'SPICED', 'HERITAGE'];
    default:
      return ['TRADITIONAL', 'LOCAL FAVORITE'];
  }
}

List<String> _defaultIngredients(String region) {
  switch (region) {
    case 'Asia':
      return ['Rice', 'Soy sauce', 'Ginger', 'Garlic', 'Sesame', 'Herbs'];
    case 'Europe':
      return ['Flour', 'Butter', 'Herbs', 'Onion', 'Garlic', 'Olive oil'];
    case 'Africa':
      return ['Grains', 'Spices', 'Tomato', 'Onion', 'Chili', 'Herbs'];
    case 'Americas':
      return ['Corn', 'Beans', 'Chili', 'Tomato', 'Cilantro', 'Lime'];
    case 'Oceania':
      return ['Seafood', 'Coconut', 'Lime', 'Herbs', 'Root vegetables'];
    default:
      return ['Salt', 'Herbs', 'Oil', 'Onion', 'Garlic'];
  }
}
