/// Restaurant catalog used by the Baku food map.
///
/// Lives in `data/` so widgets can import this without pulling in the
/// full `baku_map_screen.dart` (which creates circular imports otherwise).

class BakuRestaurant {
  const BakuRestaurant({
    required this.name,
    required this.cuisine,
    required this.flag,
    required this.lat,
    required this.lng,
    required this.neighborhood,
    this.priceRange = '₼₼',
    this.description = '',
    this.instagram,
    this.address = '',
  });

  final String name;
  final String cuisine;
  final String flag;
  final double lat;
  final double lng;
  final String neighborhood;
  final String priceRange;
  final String description;
  final String? instagram;
  final String address;
}

const kBakuRestaurants = <BakuRestaurant>[
  // Azerbaijani
  BakuRestaurant(name: 'Mugam Club', cuisine: 'Azerbaijani', flag: '🇦🇿', lat: 40.3672, lng: 49.8330, neighborhood: 'Icheri Sheher', priceRange: '₼₼₼', description: 'Traditional cuisine with live mugam music', instagram: 'mugamclub.baku', address: '9 Qosha Qala St, İçərişəhər'),
  BakuRestaurant(name: 'Sultan Inn', cuisine: 'Azerbaijani', flag: '🇦🇿', lat: 40.3660, lng: 49.8345, neighborhood: 'Old City', priceRange: '₼₼', instagram: 'sultaninn.baku', address: '7 Kichik Qala St, İçərişəhər'),
  BakuRestaurant(name: 'Chinar', cuisine: 'Azerbaijani', flag: '🇦🇿', lat: 40.3683, lng: 49.8322, neighborhood: 'Old City', priceRange: '₼₼₼', description: 'Rooftop dining with Caspian Sea views', instagram: 'chinar.restaurant', address: '12 Neftçilər Ave, Old City'),
  BakuRestaurant(name: 'Qarabag', cuisine: 'Azerbaijani', flag: '🇦🇿', lat: 40.3773, lng: 49.8415, neighborhood: 'Center', priceRange: '₼₼', instagram: 'qarabag.baku', address: '4 İstiqlaliyyət St, Baku'),
  // Japanese
  BakuRestaurant(name: 'Tokyo Garden', cuisine: 'Japanese', flag: '🇯🇵', lat: 40.3797, lng: 49.8513, neighborhood: 'Center', priceRange: '₼₼₼', instagram: 'tokyogarden.baku', address: '28 Rasul Rza St, Baku'),
  BakuRestaurant(name: 'Sumaq', cuisine: 'Japanese', flag: '🇯🇵', lat: 40.3636, lng: 49.8519, neighborhood: 'Bulvar', priceRange: '₼₼', description: 'Sushi bar on the waterfront', instagram: 'sumaq.baku', address: 'Neftçilər Ave, Bulvar'),
  BakuRestaurant(name: 'Sakura', cuisine: 'Japanese', flag: '🇯🇵', lat: 40.3802, lng: 49.8490, neighborhood: 'Nizami', priceRange: '₼₼', instagram: 'sakura.baku', address: '56 Nizami St, Baku'),
  // Italian
  BakuRestaurant(name: 'La Piazza', cuisine: 'Italian', flag: '🇮🇹', lat: 40.3790, lng: 49.8480, neighborhood: 'Nizami', priceRange: '₼₼', description: 'Authentic Neapolitan pizza', instagram: 'lapiazza.baku', address: '44 Nizami St, Baku'),
  BakuRestaurant(name: 'Dolce Vita', cuisine: 'Italian', flag: '🇮🇹', lat: 40.3805, lng: 49.8495, neighborhood: 'Nizami', priceRange: '₼₼₼', instagram: 'dolcevita.baku', address: '67 Nizami St, Baku'),
  // Indian
  BakuRestaurant(name: 'Mumbai Palace', cuisine: 'Indian', flag: '🇮🇳', lat: 40.3818, lng: 49.8522, neighborhood: 'Center', priceRange: '₼₼', instagram: 'mumbaipalace.baku', address: '15 Bülbül Ave, Baku'),
  BakuRestaurant(name: 'Taj Mahal', cuisine: 'Indian', flag: '🇮🇳', lat: 40.3825, lng: 49.8535, neighborhood: 'Center', priceRange: '₼₼₼', instagram: 'tajmahal.baku', address: '22 Bülbül Ave, Baku'),
  // Chinese
  BakuRestaurant(name: 'Dragon Palace', cuisine: 'Chinese', flag: '🇨🇳', lat: 40.3832, lng: 49.8548, neighborhood: 'Center', priceRange: '₼₼', instagram: 'dragonpalace.baku', address: '10 Hüseyn Cavid Ave, Baku'),
  BakuRestaurant(name: 'Great Wall', cuisine: 'Chinese', flag: '🇨🇳', lat: 40.3815, lng: 49.8562, neighborhood: 'Center', priceRange: '₼₼', instagram: 'greatwall.baku', address: '18 Hüseyn Cavid Ave, Baku'),
  // Turkish
  BakuRestaurant(name: 'Istanbul Sofrasi', cuisine: 'Turkish', flag: '🇹🇷', lat: 40.3787, lng: 49.8443, neighborhood: 'Fountain Sq', priceRange: '₼₼', instagram: 'istanbulsofrasi', address: '3 Fountain Square, Baku'),
  BakuRestaurant(name: 'Güller', cuisine: 'Turkish', flag: '🇹🇷', lat: 40.3793, lng: 49.8430, neighborhood: 'Fountain Sq', priceRange: '₼', instagram: 'guller.baku', address: '5 Fountain Square, Baku'),
  // Georgian
  BakuRestaurant(name: 'Tamada', cuisine: 'Georgian', flag: '🇬🇪', lat: 40.3783, lng: 49.8505, neighborhood: 'Center', priceRange: '₼₼', instagram: 'tamada.baku', address: '31 Tbilisi Ave, Baku'),
  BakuRestaurant(name: 'Tiflis', cuisine: 'Georgian', flag: '🇬🇪', lat: 40.3770, lng: 49.8493, neighborhood: 'Center', priceRange: '₼', instagram: 'tiflis.baku', address: '25 Tbilisi Ave, Baku'),
  // Lebanese
  BakuRestaurant(name: 'Beirut', cuisine: 'Lebanese', flag: '🇱🇧', lat: 40.3842, lng: 49.8488, neighborhood: 'Center', priceRange: '₼₼', instagram: 'beirut.baku', address: '8 Mirəli Qaşqay St, Baku'),
  // American
  BakuRestaurant(name: 'Texas BBQ', cuisine: 'American', flag: '🇺🇸', lat: 40.3640, lng: 49.8533, neighborhood: 'Bulvar', priceRange: '₼₼', instagram: 'texasbbq.baku', address: 'Neftçilər Ave 2, Bulvar Mall'),
  BakuRestaurant(name: 'Burger Republic', cuisine: 'American', flag: '🇺🇸', lat: 40.3813, lng: 49.8557, neighborhood: 'Center', priceRange: '₼', instagram: 'burgerrepublic.az', address: '12 Rashid Behbudov St, Baku'),
  // Korean
  BakuRestaurant(name: 'Seoul Garden', cuisine: 'Korean', flag: '🇰🇷', lat: 40.3828, lng: 49.8543, neighborhood: 'Center', priceRange: '₼₼₼', instagram: 'seoulgarden.baku', address: '20 Khagani St, Baku'),
  // French
  BakuRestaurant(name: 'La Fontaine', cuisine: 'French', flag: '🇫🇷', lat: 40.3795, lng: 49.8536, neighborhood: 'Fountain Sq', priceRange: '₼₼₼', instagram: 'lafontaine.baku', address: '1 Fountain Square, Baku'),
  // Iranian
  BakuRestaurant(name: 'Chelo Kabab', cuisine: 'Iranian', flag: '🇮🇷', lat: 40.3762, lng: 49.8463, neighborhood: 'Center', priceRange: '₼', instagram: 'chelokabab.baku', address: '40 Hüsü Hacıyev St, Baku'),
  // Thai
  BakuRestaurant(name: 'Thai Orchid', cuisine: 'Thai', flag: '🇹🇭', lat: 40.3837, lng: 49.8558, neighborhood: 'Center', priceRange: '₼₼', instagram: 'thaiorchid.baku', address: '6 Mirəli Qaşqay St, Baku'),
  // Russian
  BakuRestaurant(name: 'Rus Evi', cuisine: 'Russian', flag: '🇷🇺', lat: 40.3848, lng: 49.8473, neighborhood: 'Center', priceRange: '₼₼', instagram: 'rusevi.baku', address: '14 Vidadi St, Baku'),
  // Spanish
  BakuRestaurant(name: 'El Corazon', cuisine: 'Spanish', flag: '🇪🇸', lat: 40.3758, lng: 49.8527, neighborhood: 'Center', priceRange: '₼₼₼', description: 'Tapas & flamenco evenings', instagram: 'elcorazon.baku', address: '36 Khagani St, Baku'),
  // Ukrainian
  BakuRestaurant(name: 'Slavyanka', cuisine: 'Ukrainian', flag: '🇺🇦', lat: 40.3845, lng: 49.8472, neighborhood: 'Center', priceRange: '₼₼', instagram: 'slavyanka.baku', address: '11 Vidadi St, Baku'),
  // Mexican
  BakuRestaurant(name: 'Mexico Lindo', cuisine: 'Mexican', flag: '🇲🇽', lat: 40.3808, lng: 49.8542, neighborhood: 'Center', priceRange: '₼₼', instagram: 'mexicolindo.baku', address: '24 Rashid Behbudov St, Baku'),
  // Greek
  BakuRestaurant(name: 'Athens Grill', cuisine: 'Greek', flag: '🇬🇷', lat: 40.3780, lng: 49.8468, neighborhood: 'Center', priceRange: '₼₼', instagram: 'athensgrill.baku', address: '19 Hüsü Hacıyev St, Baku'),
];

/// Total restaurants in the Baku map (used by `MapScreen` header counter).
const kBakuRestaurantsCount = 29;

/// Maps Baku restaurant cuisine names → World-map country ISO-A2 codes.
/// Used to show the same Instax photo on both maps when a cuisine is visited.
const kCuisineToIso = <String, String>{
  'Azerbaijani': 'AZ',
  'Japanese':    'JP',
  'Italian':     'IT',
  'Indian':      'IN',
  'Chinese':     'CN',
  'Turkish':     'TR',
  'Georgian':    'GE',
  'Lebanese':    'LB',
  'American':    'US',
  'Korean':      'KR',
  'French':      'FR',
  'Iranian':     'IR',
  'Thai':        'TH',
  'Russian':     'RU',
  'Spanish':     'ES',
  'Ukrainian':   'UA',
  'Mexican':     'MX',
  'Greek':       'GR',
};
