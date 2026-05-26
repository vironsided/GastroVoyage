import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/baku/widgets/baku_action_button.dart';

/// Couples-theme restaurant detail card — references photos 10, 11, 12
/// (blue bow-seal · envelope-letter layout · vertical striped frame).
class CouplesCard extends StatelessWidget {
  const CouplesCard({
    super.key,
    required this.restaurant,
    required this.onClose,
  });

  final BakuRestaurant restaurant;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Striped background (photo 12 — blue diagonal stripes)
          Positioned.fill(
            child: CustomPaint(painter: _CouplesStripedPainter()),
          ),

          // White pill content window (photo 12)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB8D4E8), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D5280).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Blue bow wax seal (photo 10)
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD0E8F5),
                        border: Border.all(color: const Color(0xFF7BA7C7), width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            restaurant.flag,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const Text('🎀', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Info (envelope letter style — photo 11)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  restaurant.name,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2D5280),
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: onClose,
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Color(0xFF9ABBD0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${restaurant.cuisine} · ${restaurant.neighborhood}',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11,
                              color: const Color(0xFF4A7FB5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Text(
                                restaurant.priceRange,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2D5280),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (restaurant.description.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    restaurant.description,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 10,
                                      color: const Color(0xFF7A9AB0),
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: BakuActionButton(
                                  label: 'Route',
                                  icon: Icons.directions_outlined,
                                  color: const Color(0xFF4A7FB5),
                                  onTap: () => openMaps(
                                      restaurant.lat,
                                      restaurant.lng,
                                      restaurant.name),
                                ),
                              ),
                              if (restaurant.instagram != null) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: BakuActionButton(
                                    label: 'Instagram',
                                    icon: Icons.camera_alt_outlined,
                                    color: const Color(0xFF4A7FB5),
                                    outlined: true,
                                    onTap: () =>
                                        openInstagram(restaurant.instagram!),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blue diagonal-stripe background painter (photo 12).
class _CouplesStripedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFB8D4E8),
    );
    final stripe = Paint()
      ..color = const Color(0xFF90BCDA).withOpacity(0.5)
      ..strokeWidth = 7;
    for (double x = -size.height; x < size.width + size.height; x += 14) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripe,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
