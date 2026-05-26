import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/baku/widgets/baku_action_button.dart';

/// Girls-theme restaurant detail card — references photos 6, 7, 8, 9
/// (lace trim · pink stamp badge · polaroid with pink clip · pink bow seal).
class GirlsCard extends StatelessWidget {
  const GirlsCard({
    super.key,
    required this.restaurant,
    required this.onClose,
  });

  final BakuRestaurant restaurant;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0C8D8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE07A9A).withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lace-pattern top border (photo 6)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(
              height: 14,
              width: double.infinity,
              child: CustomPaint(painter: _GirlsCardLacePainter()),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Polaroid frame (photo 8)
                Container(
                  width: 78,
                  height: 98,
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(1, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Pink clip (photo 8)
                      Positioned(
                        top: -7,
                        child: Container(
                          width: 18,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDAEC0),
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Flag in photo area
                      Container(
                        color: const Color(0xFFFFF5F8),
                        child: Center(
                          child: Text(
                            restaurant.flag,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              restaurant.name,
                              style: GoogleFonts.caveat(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB5476A),
                                height: 1.1,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: onClose,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F5),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFF0C8D8)),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 13,
                                color: Color(0xFFB5476A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Stamp-style cuisine badge (photo 7)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE07A9A), width: 1.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          '${restaurant.cuisine.toUpperCase()}  ${restaurant.flag}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE07A9A),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 12, color: Color(0xFFCCA0B0)),
                          const SizedBox(width: 2),
                          Text(
                            restaurant.neighborhood,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11,
                              color: const Color(0xFFCCA0B0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        restaurant.priceRange,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB5476A),
                        ),
                      ),
                      if (restaurant.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          restaurant.description,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 10,
                            color: const Color(0xFF7A4A5A),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: BakuActionButton(
                    label: 'Route',
                    icon: Icons.directions_outlined,
                    color: const Color(0xFFE07A9A),
                    onTap: () => openMaps(
                        restaurant.lat, restaurant.lng, restaurant.name),
                  ),
                ),
                if (restaurant.instagram != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: BakuActionButton(
                      label: 'Instagram',
                      icon: Icons.camera_alt_outlined,
                      color: const Color(0xFFE07A9A),
                      outlined: true,
                      onTap: () => openInstagram(restaurant.instagram!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lace-pattern painter (photo 6 — white lace trim with semi-circle dots
/// punched both top and bottom). Distinct from the kit's `LacePainter` which
/// only handles a single-edge dotted scalloped line.
class _GirlsCardLacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFFF0F5),
    );
    final fill = Paint()..color = const Color(0xFFF5D0DF);
    const count = 28;
    final w = size.width / count;
    for (int i = 0; i < count; i++) {
      canvas.drawCircle(Offset(w * i + w / 2, size.height), w * 0.44, fill);
      canvas.drawCircle(Offset(w * i + w / 2, 0), w * 0.3, fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
