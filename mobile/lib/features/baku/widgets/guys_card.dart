import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/baku/data/baku_restaurant.dart';
import 'package:mobile/features/baku/widgets/baku_action_button.dart';

/// Guys-theme restaurant detail card — references photos 13, 14, 15, 17
/// (chrome metallic accents · plumbob green accent · dark moody slab).
class GuysCard extends StatelessWidget {
  const GuysCard({
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
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00CC00).withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Colors.black,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Flag column
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(restaurant.flag, style: const TextStyle(fontSize: 32)),
              ],
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF333333)),
                          ),
                          child: const Icon(Icons.close,
                              size: 13, color: Color(0xFF666666)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // Chrome music note (photo 15) + cuisine info
                  Row(
                    children: [
                      const Text(
                        '♪',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF00CC00),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${restaurant.cuisine}  ·  ${restaurant.neighborhood}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00CC00),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          restaurant.priceRange,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (restaurant.description.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            restaurant.description,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 10,
                              color: const Color(0xFF555555),
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: BakuActionButton(
                          label: 'Route',
                          icon: Icons.directions_outlined,
                          color: const Color(0xFF00CC00),
                          onTap: () => openMaps(
                              restaurant.lat, restaurant.lng, restaurant.name),
                        ),
                      ),
                      if (restaurant.instagram != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: BakuActionButton(
                            label: 'Instagram',
                            icon: Icons.camera_alt_outlined,
                            color: const Color(0xFF00CC00),
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
    );
  }
}
