import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/couples/data/couple_models.dart';
import 'package:mobile/features/couples/data/couple_providers.dart';
import 'package:mobile/features/explore/dish_catalog.dart';
import 'package:mobile/features/explore/ingredient_images.dart';
import 'package:mobile/features/shared/models.dart';

class DishDetailScreen extends ConsumerStatefulWidget {
  const DishDetailScreen({super.key, required this.country});

  final Country country;

  @override
  ConsumerState<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends ConsumerState<DishDetailScreen> {
  bool _showLogForm = false;
  bool _showEditForm = false;
  bool _saving = false;
  bool _pickingPhoto = false;
  // Picked photo as an XFile so we can read bytes on web (where File from
  // dart:io can't wrap the picker's blob: URL) and as a real file on native.
  XFile? _pickedPhoto;
  // Cached preview bytes — populated when the picker returns so the local
  // preview shows immediately without re-reading the XFile on every rebuild.
  Uint8List? _pickedPhotoBytes;
  final _notesCtrl = TextEditingController();
  int _rating = 5;
  DateTime _date = DateTime.now();
  Visit? _editingVisit;

  /// Baku restaurant the user attached this visit to (optional).
  String? _restaurantName;

  /// Four optional sub-ratings. Null until the user actually taps a star.
  /// Sent to the backend only when non-null; legacy visits keep showing the
  /// single overall rating with no detail strip.
  int? _atmosphere;
  int? _service;
  int? _value;
  int? _dish;

  /// "We were together" tag — only meaningful when the user has an active
  /// couple link. Stored on the visit row (migration 015 `with_partner`).
  bool _withPartner = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Baku restaurants whose cuisine maps (via [kCuisineToIso]) to this
  /// country's ISO code. Empty when the country has no Baku counterpart —
  /// in that case the restaurant picker is not shown at all.
  List<BakuRestaurant> get _bakuRestaurantsForCountry {
    final iso = widget.country.isoA2.toUpperCase();
    final cuisines = kCuisineToIso.entries
        .where((e) => e.value.toUpperCase() == iso)
        .map((e) => e.key)
        .toSet();
    if (cuisines.isEmpty) return const <BakuRestaurant>[];
    return kBakuRestaurants
        .where((r) => cuisines.contains(r.cuisine))
        .toList();
  }

  Visit? _visitForCountry(List<Visit> visits) {
    final matches =
        visits.where((v) => v.countryId == widget.country.id).toList();
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.visitedOn.compareTo(a.visitedOn));
    return matches.first;
  }

  DateTime _parseDate(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return DateTime.now();
    }
  }

  void _openLogForm() {
    setState(() {
      _showLogForm = true;
      _showEditForm = false;
      _notesCtrl.clear();
      _rating = 5;
      _date = DateTime.now();
      _pickedPhoto = null;
      _pickedPhotoBytes = null;
      _editingVisit = null;
      _restaurantName = null;
      _atmosphere = null;
      _service = null;
      _value = null;
      _dish = null;
      _withPartner = false;
    });
  }

  void _openEditForm(Visit visit) {
    setState(() {
      _showEditForm = true;
      _showLogForm = false;
      _editingVisit = visit;
      _notesCtrl.text = visit.notes;
      _rating = visit.rating;
      _date = _parseDate(visit.visitedOn);
      _pickedPhoto = null;
      _pickedPhotoBytes = null;
      // Keep the picked restaurant only if it still matches an existing option.
      final options = _bakuRestaurantsForCountry.map((r) => r.name).toSet();
      _restaurantName = options.contains(visit.restaurantName)
          ? visit.restaurantName
          : null;
      _atmosphere = visit.atmosphereRating;
      _service = visit.serviceRating;
      _value = visit.valueRating;
      _dish = visit.dishRating;
      _withPartner = visit.withPartner;
    });
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        if (mounted) {
          setState(() {
            _pickedPhoto = xfile;
            _pickedPhotoBytes = bytes;
          });
          _offerAiAutofill(xfile);
        }
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  /// Pop a SnackBar offering Claude vision auto-fill — non-blocking, easy
  /// to dismiss. Only fires the AI call when the user opts in, so we never
  /// burn tokens silently.
  void _offerAiAutofill(XFile xfile) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        content: const Text('Let Claude pre-fill dish + ratings from this photo?'),
        action: SnackBarAction(
          label: 'Let AI suggest',
          onPressed: () => _runAiAutofill(xfile),
        ),
      ),
    );
  }

  Future<void> _runAiAutofill(XFile xfile) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Claude is reading the photo…')),
    );
    try {
      final suggestion =
          await ref.read(apiClientProvider).aiParseVisitPhoto(xfile);
      if (!mounted) return;
      // Apply non-destructively: only fill empty fields, never clobber what
      // the user already typed.
      setState(() {
        if (_notesCtrl.text.trim().isEmpty &&
            (suggestion.suggestedNotes?.isNotEmpty ?? false)) {
          _notesCtrl.text = suggestion.suggestedNotes!;
        }
        _dish ??= suggestion.suggestedDishRating;
        _atmosphere ??= suggestion.suggestedAtmosphereRating;
      });
      messenger.hideCurrentSnackBar();
      final dish = suggestion.dishName ?? 'this dish';
      final conf = suggestion.confidence;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'AI: $dish · $conf confidence. Review and edit before saving.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final s = e.toString();
      final msg = s.contains('503')
          ? 'AI is not configured on this server yet.'
          : s.contains('415')
              ? 'Photo format not supported by AI.'
              : 'AI auto-fill failed. Fill the form yourself.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _saveNew() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      String? photoUrl;
      if (_pickedPhoto != null) {
        photoUrl = await api.uploadPhoto(_pickedPhoto!);
      }
      await api.createVisit(
        countryId: widget.country.id,
        notes: _notesCtrl.text.trim(),
        rating: _rating,
        visitedOn: DateFormat('yyyy-MM-dd').format(_date),
        photoUrl: photoUrl,
        restaurantName: _restaurantName,
        atmosphereRating: _atmosphere,
        serviceRating: _service,
        valueRating: _value,
        dishRating: _dish,
        withPartner: _withPartner ? true : null,
      );
      _invalidateAll();
      if (mounted) {
        setState(() {
          _showLogForm = false;
          _pickedPhoto = null;
          _pickedPhotoBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit logged!')),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveEdit() async {
    final visit = _editingVisit;
    if (visit == null) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      String? photoPath;
      if (_pickedPhoto != null) {
        photoPath = await api.uploadPhoto(_pickedPhoto!);
      }
      await api.updateVisit(
        visitId: visit.id,
        notes: _notesCtrl.text.trim(),
        rating: _rating,
        visitedOn: DateFormat('yyyy-MM-dd').format(_date),
        photoPath: photoPath,
        restaurantName: _restaurantName,
        atmosphereRating: _atmosphere,
        serviceRating: _service,
        valueRating: _value,
        dishRating: _dish,
        withPartner: _withPartner,
      );
      _invalidateAll();
      if (mounted) {
        setState(() => _showEditForm = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit updated')),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Visit visit) async {
    final config = ref.read(gastroThemeConfigProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: config.surface,
        title: Text(
          'Remove visit?',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: config.onSurface,
          ),
        ),
        content: Text(
          'This removes your mark for ${widget.country.name}. '
          'You can log it again later if you change your mind.',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: config.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: config.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: config.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).deleteVisit(visit.id);
      _invalidateAll();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit removed')),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _invalidateAll() {
    ref.invalidate(visitsProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(mapCountriesProvider);
    ref.invalidate(exploreCountriesProvider);
  }

  void _showError(Object e) {
    if (!mounted) return;
    final config = ref.read(gastroThemeConfigProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: config.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(gastroThemeConfigProvider);
    final country = widget.country;
    final entry = catalogFor(
      isoA2: country.isoA2,
      region: country.region,
      countryName: country.name,
    );
    final visitsAsync = ref.watch(visitsProvider);
    final visit = visitsAsync.maybeWhen(
      data: (list) => _visitForCountry(list),
      orElse: () => null,
    );
    final visited = country.visited || visit != null;

    return Scaffold(
      backgroundColor: config.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: config.background,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: config.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    entry.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: config.accentSoft,
                      child: Icon(LucideIcons.utensils,
                          size: 48, color: config.accent),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: entry.categories
                        .map((c) => Text(
                              c,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                letterSpacing: 1.2,
                                color: config.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.dish,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: config.onSurface,
                                height: 1.1,
                              ),
                            ),
                            if (entry.alternateNames.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                entry.alternateNames.join(', '),
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12,
                                  color: config.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CountryMapCard(country: country, config: config),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        country.flagEmoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        country.name.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: config.accent,
                        ),
                      ),
                      Text(
                        ' · ${country.subregion}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12,
                          color: config.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        entry.rating.toStringAsFixed(1),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: config.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < entry.rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 22,
                          color: config.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...entry.description.split('\n\n').map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            p,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 15,
                              height: 1.55,
                              color: config.onSurface.withOpacity(0.92),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 8),
                  Text(
                    'INGREDIENTS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: config.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 102,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: entry.ingredients.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _IngredientChip(
                        label: entry.ingredients[i],
                        config: config,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (visited && visit != null && !_showLogForm && !_showEditForm)
                    _VisitedBanner(
                      config: config,
                      visit: visit,
                      onEdit: () => _openEditForm(visit),
                      onDelete: () => _confirmDelete(visit),
                    ),
                  if (_showLogForm || _showEditForm)
                    _VisitForm(
                      config: config,
                      notesCtrl: _notesCtrl,
                      rating: _rating,
                      date: _date,
                      pickedPhotoBytes: _pickedPhotoBytes,
                      pickingPhoto: _pickingPhoto,
                      saving: _saving,
                      isEdit: _showEditForm,
                      restaurantOptions: _bakuRestaurantsForCountry,
                      restaurantName: _restaurantName,
                      atmosphere: _atmosphere,
                      service: _service,
                      valueRating: _value,
                      dish: _dish,
                      withPartner: _withPartner,
                      partner: ref.watch(myCoupleProvider).valueOrNull,
                      onRating: (r) => setState(() => _rating = r),
                      onDate: (d) => setState(() => _date = d),
                      onPickPhoto: _pickPhoto,
                      onClearPhoto: () => setState(() {
                        _pickedPhoto = null;
                        _pickedPhotoBytes = null;
                      }),
                      onRestaurant: (name) =>
                          setState(() => _restaurantName = name),
                      onAtmosphere: (v) => setState(() => _atmosphere = v),
                      onService: (v) => setState(() => _service = v),
                      onValue: (v) => setState(() => _value = v),
                      onDish: (v) => setState(() => _dish = v),
                      onWithPartner: (v) => setState(() => _withPartner = v),
                      onCancel: () => setState(() {
                        _showLogForm = false;
                        _showEditForm = false;
                      }),
                      onSave: _showEditForm ? _saveEdit : _saveNew,
                    )
                  else if (!_showLogForm && !_showEditForm) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openLogForm,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          visited ? 'Log Another Visit' : 'Ate it? Log your visit',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: config.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini map card ─────────────────────────────────────────────────────────────

class _CountryMapCard extends StatefulWidget {
  const _CountryMapCard({required this.country, required this.config});
  final Country country;
  final GastroThemeConfig config;

  @override
  State<_CountryMapCard> createState() => _CountryMapCardState();
}

class _CountryMapCardState extends State<_CountryMapCard> {
  late Future<bool> _exists;

  @override
  void initState() {
    super.initState();
    _exists = _checkAsset();
  }

  Future<bool> _checkAsset() async {
    try {
      final path = 'assets/maps/countries/${widget.country.isoA2.toLowerCase()}.svg';
      await DefaultAssetBundle.of(context).load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iso = widget.country.isoA2.toLowerCase();
    final placeholder = Center(
      child: Icon(Icons.map_outlined, size: 20,
          color: widget.config.accent.withOpacity(0.4)),
    );

    return Container(
      width: 100,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: FutureBuilder<bool>(
          future: _exists,
          builder: (context, snap) {
            if (snap.data != true) return placeholder;
            return SvgPicture.asset(
              'assets/maps/countries/$iso.svg',
              fit: BoxFit.cover,
              placeholderBuilder: (_) => placeholder,
            );
          },
        ),
      ),
    );
  }
}

class _IngredientChip extends StatefulWidget {
  const _IngredientChip({required this.label, required this.config});
  final String label;
  final GastroThemeConfig config;

  @override
  State<_IngredientChip> createState() => _IngredientChipState();
}

class _IngredientChipState extends State<_IngredientChip> {
  int _urlIndex = 0;

  void _tryNextUrl() {
    final urls = ingredientImageUrls(widget.label);
    if (_urlIndex < urls.length - 1) {
      setState(() => _urlIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = ingredientImageUrls(widget.label);
    final imageUrl = urls[_urlIndex.clamp(0, urls.length - 1)];
    final exhausted = _urlIndex >= urls.length - 1;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: widget.config.isDark
                ? const Color(0xFFFAF8F5)
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.config.isDark ? 0.25 : 0.10),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              key: ValueKey(imageUrl),
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              placeholder: (_, __) => Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.config.accent.withOpacity(0.5),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) {
                if (!exhausted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _tryNextUrl();
                  });
                  return Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.config.accent.withOpacity(0.5),
                      ),
                    ),
                  );
                }
                return _IngredientFallback(
                  label: widget.label,
                  config: widget.config,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 72,
          child: Text(
            widget.label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              color: widget.config.onSurfaceVariant,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _IngredientFallback extends StatelessWidget {
  const _IngredientFallback({required this.label, required this.config});
  final String label;
  final GastroThemeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: config.surfaceVariant,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.leaf, size: 18, color: config.accent),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 7,
                color: config.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitedBanner extends StatelessWidget {
  const _VisitedBanner({
    required this.config,
    required this.visit,
    required this.onEdit,
    required this.onDelete,
  });

  final GastroThemeConfig config;
  final Visit visit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    DateTime? d;
    try {
      d = DateTime.parse(visit.visitedOn);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: config.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You tried this cuisine',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: config.accent,
                  ),
                ),
              ),
            ],
          ),
          if (d != null) ...[
            const SizedBox(height: 6),
            Text(
              DateFormat('MMMM d, yyyy').format(d),
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: config.onSurfaceVariant,
              ),
            ),
          ],
          if (visit.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              visit.notes,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: config.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit date & notes'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: config.onSurface,
                    side: BorderSide(color: config.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: config.error),
                tooltip: 'Remove visit',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitForm extends StatelessWidget {
  const _VisitForm({
    required this.config,
    required this.notesCtrl,
    required this.rating,
    required this.date,
    required this.pickedPhotoBytes,
    required this.pickingPhoto,
    required this.saving,
    required this.isEdit,
    required this.restaurantOptions,
    required this.restaurantName,
    required this.atmosphere,
    required this.service,
    required this.valueRating,
    required this.dish,
    required this.withPartner,
    required this.partner,
    required this.onRating,
    required this.onDate,
    required this.onPickPhoto,
    required this.onClearPhoto,
    required this.onRestaurant,
    required this.onAtmosphere,
    required this.onService,
    required this.onValue,
    required this.onDish,
    required this.onWithPartner,
    required this.onCancel,
    required this.onSave,
  });

  final GastroThemeConfig config;
  final TextEditingController notesCtrl;
  final int rating;
  final DateTime date;
  // Preview bytes for a freshly-picked photo. Decoupled from any File so the
  // form renders identically on native and web.
  final Uint8List? pickedPhotoBytes;
  final bool pickingPhoto;
  final bool saving;
  final bool isEdit;

  /// Baku restaurants matching this country's cuisine. Empty → no picker.
  final List<BakuRestaurant> restaurantOptions;

  /// Currently chosen Baku restaurant name, or null for "none".
  final String? restaurantName;

  /// Four optional sub-ratings. `null` means the user hasn't rated this
  /// facet — the row renders empty outline stars and no value is sent to
  /// the backend.
  final int? atmosphere;
  final int? service;
  final int? valueRating;
  final int? dish;

  /// "We were together" toggle. Only meaningful when [partner] is non-null
  /// and active — the toggle is hidden otherwise so single users don't see
  /// a confusing orphan checkbox.
  final bool withPartner;

  /// Current accepted couple link, or null/pending. Drives the heart-toggle
  /// visibility.
  final Couple? partner;

  final ValueChanged<int> onRating;
  final ValueChanged<DateTime> onDate;
  final VoidCallback onPickPhoto;
  final VoidCallback onClearPhoto;
  final ValueChanged<String?> onRestaurant;
  final ValueChanged<int?> onAtmosphere;
  final ValueChanged<int?> onService;
  final ValueChanged<int?> onValue;
  final ValueChanged<int?> onDish;
  final ValueChanged<bool> onWithPartner;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEdit ? 'Edit your visit' : 'Log your visit',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: config.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            maxLines: 3,
            style: GoogleFonts.hankenGrotesk(color: config.onSurface),
            decoration: InputDecoration(
              hintText: 'What did you taste? Where?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onPickPhoto,
            child: Container(
              height: pickedPhotoBytes != null ? 120 : 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: config.surfaceVariant,
                border: Border.all(color: config.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: pickedPhotoBytes != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(pickedPhotoBytes!, fit: BoxFit.cover),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: IconButton(
                            onPressed: onClearPhoto,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: pickingPhoto
                          ? const CircularProgressIndicator()
                          : Text(
                              'Add photo (optional)',
                              style: GoogleFonts.hankenGrotesk(
                                color: config.onSurfaceVariant,
                              ),
                            ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
              (i) => IconButton(
                onPressed: () => onRating(i + 1),
                icon: Icon(
                  i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: config.gold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _SubRatingsBlock(
            config: config,
            atmosphere: atmosphere,
            service: service,
            valueRating: valueRating,
            dish: dish,
            onAtmosphere: onAtmosphere,
            onService: onService,
            onValue: onValue,
            onDish: onDish,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) onDate(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: config.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: config.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('MMMM d, yyyy').format(date),
                    style: GoogleFonts.hankenGrotesk(color: config.onSurface),
                  ),
                ],
              ),
            ),
          ),
          if (restaurantOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RestaurantPicker(
              config: config,
              options: restaurantOptions,
              selected: restaurantName,
              onSelect: onRestaurant,
            ),
          ],
          // "We were together" — only when an active couple link exists.
          // Hidden otherwise so singles never see a confusing orphan toggle.
          if (partner != null && partner!.status == CoupleStatus.accepted) ...[
            const SizedBox(height: 16),
            _WithPartnerToggle(
              config: config,
              value: withPartner,
              partnerName: partner!.partner.name,
              onChanged: onWithPartner,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: saving ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: config.accent,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEdit ? 'Save changes' : 'Save visit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Baku restaurant picker ────────────────────────────────────────────────────

/// Optional picker that lets the user attach a visit to a SPECIFIC Baku
/// restaurant. Shown only when the dish's country has a matching cuisine on
/// the Baku map. "None" leaves the visit unattached (default behaviour).
class _RestaurantPicker extends StatelessWidget {
  const _RestaurantPicker({
    required this.config,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final GastroThemeConfig config;
  final List<BakuRestaurant> options;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHERE IN BAKU? (OPTIONAL)',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            letterSpacing: 1.2,
            color: config.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pin this visit to a restaurant to see your photo on the Baku map.',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12,
            color: config.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(label: 'None', value: null),
            for (final r in options) _chip(label: r.name, value: r.name),
          ],
        ),
      ],
    );
  }

  Widget _chip({required String label, required String? value}) {
    final isActive = selected == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? config.accent : config.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? config.accent : config.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : config.onSurface,
          ),
        ),
      ),
    );
  }
}

// ── Sub-ratings block ─────────────────────────────────────────────────────────

/// Four optional 1–5 micro-rating rows (Atmosphere / Service / Value / Dish).
/// Each row is a label + small star strip; tapping a star sets that facet,
/// tapping the currently-selected value clears it back to "not rated". The
/// block self-collapses behind a small "ADD DETAILS" toggle so the form is
/// not visually noisy for users who only want to log a quick overall rating.
class _SubRatingsBlock extends StatefulWidget {
  const _SubRatingsBlock({
    required this.config,
    required this.atmosphere,
    required this.service,
    required this.valueRating,
    required this.dish,
    required this.onAtmosphere,
    required this.onService,
    required this.onValue,
    required this.onDish,
  });

  final GastroThemeConfig config;
  final int? atmosphere;
  final int? service;
  final int? valueRating;
  final int? dish;
  final ValueChanged<int?> onAtmosphere;
  final ValueChanged<int?> onService;
  final ValueChanged<int?> onValue;
  final ValueChanged<int?> onDish;

  @override
  State<_SubRatingsBlock> createState() => _SubRatingsBlockState();
}

class _SubRatingsBlockState extends State<_SubRatingsBlock> {
  late bool _expanded = _hasAnyRating;

  bool get _hasAnyRating =>
      widget.atmosphere != null ||
      widget.service != null ||
      widget.valueRating != null ||
      widget.dish != null;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final filledCount = [
      widget.atmosphere,
      widget.service,
      widget.valueRating,
      widget.dish,
    ].where((v) => v != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_more : Icons.chevron_right,
                size: 18,
                color: config.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _expanded ? 'DETAILS (OPTIONAL)' : 'ADD DETAILS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: config.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!_expanded && filledCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$filledCount/4',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: config.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: [
                      _SubRatingRow(
                        config: config,
                        label: 'Atmosphere',
                        value: widget.atmosphere,
                        onChange: widget.onAtmosphere,
                      ),
                      _SubRatingRow(
                        config: config,
                        label: 'Service',
                        value: widget.service,
                        onChange: widget.onService,
                      ),
                      _SubRatingRow(
                        config: config,
                        label: 'Value',
                        value: widget.valueRating,
                        onChange: widget.onValue,
                      ),
                      _SubRatingRow(
                        config: config,
                        label: 'Dish',
                        value: widget.dish,
                        onChange: widget.onDish,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _SubRatingRow extends StatelessWidget {
  const _SubRatingRow({
    required this.config,
    required this.label,
    required this.value,
    required this.onChange,
  });

  final GastroThemeConfig config;
  final String label;
  final int? value;
  final ValueChanged<int?> onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: config.onSurface,
              ),
            ),
          ),
          for (int i = 1; i <= 5; i++)
            GestureDetector(
              onTap: () {
                // Tap an already-selected pip to clear (back to "not rated").
                if (value == i) {
                  onChange(null);
                } else {
                  onChange(i);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                child: Icon(
                  (value ?? 0) >= i
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 20,
                  color: (value ?? 0) >= i
                      ? config.gold
                      : config.onSurfaceVariant.withOpacity(0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── "We were together" toggle ───────────────────────────────────────────────

/// Heart-shaped toggle that marks the current visit as eaten together with
/// the user's partner. Only rendered when there's an accepted couple link
/// (the visit form keeps it hidden otherwise).
class _WithPartnerToggle extends StatelessWidget {
  const _WithPartnerToggle({
    required this.config,
    required this.value,
    required this.partnerName,
    required this.onChanged,
  });

  final GastroThemeConfig config;
  final bool value;
  final String partnerName;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? config.accentSoft : config.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? config.accent : config.outlineVariant,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              value ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              size: 22,
              color: value ? config.accent : config.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We were together',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: config.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value
                        ? 'Counts as a joint bite with $partnerName.'
                        : "Tap if you ate this with $partnerName.",
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      color: config.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
