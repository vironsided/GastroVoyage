/// Curated rotation of 30 "dish of the day" suggestions — one per day of
/// the month-ish, recycling forever. Each entry is a hand-picked dish that
/// pairs with a real Baku restaurant of the matching cuisine, so the
/// dashboard nudge "Today's dish — try it at {restaurant}" lands somewhere
/// real.
///
/// Pure data, no Flutter / no provider. The dashboard widget picks the
/// dish for today via `dailyDishForToday()`, which uses the local
/// day-of-year so every user sees the same dish on the same day (no
/// account-specific drift). Friends comparing apps in person get a shared
/// reference point.

class DailyDish {
  const DailyDish({
    required this.flag,
    required this.country,
    required this.cuisine,
    required this.dish,
    required this.blurb,
    required this.restaurantHint,
  });

  /// 🇮🇹-style emoji flag of the cuisine's home country.
  final String flag;

  /// Display name of the country (e.g. "Italy").
  final String country;

  /// Cuisine label — matches `BakuRestaurant.cuisine` strings so the UI can
  /// surface a recommended Baku spot of that cuisine.
  final String cuisine;

  /// The signature dish (e.g. "Cacio e Pepe").
  final String dish;

  /// 1-2 sentence handwritten-feeling blurb (Caveat-styled) — what makes
  /// this dish worth your evening.
  final String blurb;

  /// Suggested Baku restaurant by name (a known entry in
  /// `lib/features/baku/data/baku_restaurant.dart`). Surfaced as a hint
  /// even when the runtime lookup of the BakuRestaurant by cuisine returns
  /// multiple options — the card shows this one first.
  final String restaurantHint;
}

/// The 30-day rotation. Order is the rotation index — `dailyDishForToday()`
/// picks `dishes[dayOfYear % dishes.length]`, so swapping the order rotates
/// the schedule.
const List<DailyDish> kDailyDishes = [
  DailyDish(
    flag: '🇯🇵', country: 'Japan', cuisine: 'Japanese',
    dish: 'Tonkotsu Ramen',
    blurb: 'A bowl that hugs you back — pork-bone broth simmered for hours, '
        'soft egg, and a sheet of nori that smells like the sea.',
    restaurantHint: 'Sumaq',
  ),
  DailyDish(
    flag: '🇮🇹', country: 'Italy', cuisine: 'Italian',
    dish: 'Cacio e Pepe',
    blurb: 'Three ingredients — pasta, pecorino, black pepper — and somehow '
        'an entire grandmother\'s love language.',
    restaurantHint: 'La Piazza',
  ),
  DailyDish(
    flag: '🇪🇸', country: 'Spain', cuisine: 'Spanish',
    dish: 'Patatas Bravas',
    blurb: 'Crispy potato cubes that demand to be shared, drowned in a '
        'smoky-spicy aioli that ruins all other potatoes for you.',
    restaurantHint: 'El Corazon',
  ),
  DailyDish(
    flag: '🇬🇷', country: 'Greece', cuisine: 'Greek',
    dish: 'Moussaka',
    blurb: 'Layers of eggplant, spiced lamb, and a béchamel blanket that '
        'somehow tastes like a sunset on Santorini.',
    restaurantHint: 'Athens Grill',
  ),
  DailyDish(
    flag: '🇬🇪', country: 'Georgia', cuisine: 'Georgian',
    dish: 'Khinkali',
    blurb: 'Pleated soup dumplings — bite the side, sip the broth, never '
        'eat the knot. Anything else is amateur hour.',
    restaurantHint: 'Tamada',
  ),
  DailyDish(
    flag: '🇱🇧', country: 'Lebanon', cuisine: 'Lebanese',
    dish: 'Hummus with Lamb',
    blurb: 'Silky hummus crowned with spiced lamb and pine nuts — the kind '
        'of plate that makes pita feel like a duty, not a side.',
    restaurantHint: 'Beirut',
  ),
  DailyDish(
    flag: '🇹🇷', country: 'Türkiye', cuisine: 'Turkish',
    dish: 'Adana Kebab',
    blurb: 'Hand-minced lamb on a wide skewer, smoke and chili in every '
        'bite. Order extra grilled tomato, thank me later.',
    restaurantHint: 'Istanbul Sofrasi',
  ),
  DailyDish(
    flag: '🇫🇷', country: 'France', cuisine: 'French',
    dish: 'Coq au Vin',
    blurb: 'Chicken slow-braised in red wine until it forgets it was ever '
        'chicken. Bread is mandatory.',
    restaurantHint: 'La Fontaine',
  ),
  DailyDish(
    flag: '🇮🇳', country: 'India', cuisine: 'Indian',
    dish: 'Butter Chicken',
    blurb: 'Tomato, cream, and a quiet smoke from the tandoor. The dish '
        'that converts the skeptics. Garlic naan or it didn\'t happen.',
    restaurantHint: 'Saffron',
  ),
  DailyDish(
    flag: '🇨🇳', country: 'China', cuisine: 'Chinese',
    dish: 'Mapo Tofu',
    blurb: 'Silken tofu in a Sichuan chili-bean sauce that makes your lips '
        'tingle and your soul wake up. Numbing in the best way.',
    restaurantHint: 'Chinar',
  ),
  DailyDish(
    flag: '🇦🇿', country: 'Azerbaijan', cuisine: 'Azerbaijani',
    dish: 'Plov',
    blurb: 'Saffron rice crowned with lamb, dried fruits and a crackling '
        'kazmag crust. Sunday lunch in edible form.',
    restaurantHint: 'Qarabag',
  ),
  DailyDish(
    flag: '🇹🇭', country: 'Thailand', cuisine: 'Thai',
    dish: 'Pad Krapow Moo',
    blurb: 'Holy basil, chili, garlic and minced pork over rice with a '
        'crispy fried egg. The fastest dinner that tastes like a vacation.',
    restaurantHint: 'Thai Garden',
  ),
  DailyDish(
    flag: '🇲🇽', country: 'Mexico', cuisine: 'Mexican',
    dish: 'Tacos al Pastor',
    blurb: 'Pork shaved from a spinning trompo, pineapple on top, cilantro, '
        'lime. Hand-held happiness.',
    restaurantHint: 'Pico de Gallo',
  ),
  DailyDish(
    flag: '🇰🇷', country: 'Korea', cuisine: 'Korean',
    dish: 'Bibimbap',
    blurb: 'A stone bowl of warm rice, sautéed vegetables, gochujang and a '
        'runny egg. Stir it all — chaos becomes harmony.',
    restaurantHint: 'Seoul Tower',
  ),
  DailyDish(
    flag: '🇻🇳', country: 'Vietnam', cuisine: 'Vietnamese',
    dish: 'Bún Bò Huế',
    blurb: 'Lemongrass beef broth, fat rice noodles, fresh herbs. '
        'Hangover\'s natural enemy.',
    restaurantHint: 'Pho House',
  ),
  DailyDish(
    flag: '🇲🇦', country: 'Morocco', cuisine: 'Moroccan',
    dish: 'Lamb Tagine with Apricot',
    blurb: 'Slow-cooked lamb perfumed with cinnamon, ginger, saffron — '
        'sweet from dried apricots. Eat with bread, no fork.',
    restaurantHint: 'Marrakesh',
  ),
  DailyDish(
    flag: '🇮🇷', country: 'Iran', cuisine: 'Iranian',
    dish: 'Ghormeh Sabzi',
    blurb: 'Herb stew with lamb, kidney beans, dried lime — green, deep, '
        'patient cooking. Persian comfort.',
    restaurantHint: 'Shahnameh',
  ),
  DailyDish(
    flag: '🇵🇪', country: 'Peru', cuisine: 'Peruvian',
    dish: 'Lomo Saltado',
    blurb: 'Andean stir-fry — beef, onions, tomatoes, soy sauce — with '
        'french fries AND rice. Twice the carbs, twice the joy.',
    restaurantHint: 'El Corazon',
  ),
  DailyDish(
    flag: '🇧🇷', country: 'Brazil', cuisine: 'Brazilian',
    dish: 'Feijoada',
    blurb: 'Black bean stew with smoked pork. Rice, collards, orange on '
        'the side. Saturday lunch that becomes Saturday nap.',
    restaurantHint: 'Brasileiros',
  ),
  DailyDish(
    flag: '🇦🇷', country: 'Argentina', cuisine: 'Argentinian',
    dish: 'Asado with Chimichurri',
    blurb: 'Grilled beef over wood, bright herby chimichurri on the side. '
        'Patience is the only seasoning that matters.',
    restaurantHint: 'El Corazon',
  ),
  DailyDish(
    flag: '🇪🇹', country: 'Ethiopia', cuisine: 'Ethiopian',
    dish: 'Doro Wat with Injera',
    blurb: 'Spiced chicken stew scooped with sour spongey injera. Eat with '
        'your hands; that\'s the rule.',
    restaurantHint: 'Habesha',
  ),
  DailyDish(
    flag: '🇨🇺', country: 'Cuba', cuisine: 'Cuban',
    dish: 'Ropa Vieja',
    blurb: 'Shredded beef in tomato-pepper sauce. The name means "old '
        'clothes". Tastes like the opposite.',
    restaurantHint: 'Havana',
  ),
  DailyDish(
    flag: '🇩🇪', country: 'Germany', cuisine: 'German',
    dish: 'Schnitzel with Potato Salad',
    blurb: 'Pounded veal in golden crumbs, lemon wedge, vinegary warm '
        'potato salad. No-nonsense joy.',
    restaurantHint: 'Bavaria',
  ),
  DailyDish(
    flag: '🇵🇹', country: 'Portugal', cuisine: 'Portuguese',
    dish: 'Bacalhau à Brás',
    blurb: 'Salt cod with onions, matchstick potatoes and scrambled egg. '
        'Olives on the side. A Lisbon bar in a bowl.',
    restaurantHint: 'Lisboa',
  ),
  DailyDish(
    flag: '🇮🇸', country: 'Iceland', cuisine: 'Nordic',
    dish: 'Plokkfiskur',
    blurb: 'Mashed fish-and-potato comfort food. Eat with rye bread, '
        'butter, and a window onto rain.',
    restaurantHint: 'Nordic Kitchen',
  ),
  DailyDish(
    flag: '🇮🇩', country: 'Indonesia', cuisine: 'Indonesian',
    dish: 'Nasi Goreng',
    blurb: 'Wok-fried rice with kecap manis, fried egg on top, prawn '
        'crackers on the side. Street food perfection.',
    restaurantHint: 'Bali',
  ),
  DailyDish(
    flag: '🇵🇰', country: 'Pakistan', cuisine: 'Pakistani',
    dish: 'Nihari',
    blurb: 'Slow-cooked beef shank in a spiced gravy, eaten with naan at '
        'dawn (or dinner). The original low-and-slow.',
    restaurantHint: 'Karachi',
  ),
  DailyDish(
    flag: '🇲🇾', country: 'Malaysia', cuisine: 'Malaysian',
    dish: 'Char Kway Teow',
    blurb: 'Wok-fried rice noodles with prawns, sausage, egg and chives. '
        'Born in Penang, perfected nowhere else.',
    restaurantHint: 'Kuala',
  ),
  DailyDish(
    flag: '🇨🇴', country: 'Colombia', cuisine: 'Colombian',
    dish: 'Bandeja Paisa',
    blurb: 'A platter — beans, rice, chicharrón, plantain, avocado, fried '
        'egg, arepa. One plate, one nation.',
    restaurantHint: 'Medellin',
  ),
  DailyDish(
    flag: '🇷🇺', country: 'Russia', cuisine: 'Russian',
    dish: 'Pelmeni with Sour Cream',
    blurb: 'Tiny meat dumplings, a spoon of sour cream, a sprinkle of '
        'dill. Winter on a fork.',
    restaurantHint: 'Russkaya',
  ),
];

/// The dish to feature on the dashboard *today*. Uses the device's local
/// day-of-year so the rotation is deterministic + shared across users.
DailyDish dailyDishForToday({DateTime? now}) {
  final today = now ?? DateTime.now();
  // `dayOfYear` in [1..366]; subtract one so day 1 maps to index 0.
  final start = DateTime(today.year, 1, 1);
  final dayOfYear = today.difference(start).inDays;
  return kDailyDishes[dayOfYear % kDailyDishes.length];
}
