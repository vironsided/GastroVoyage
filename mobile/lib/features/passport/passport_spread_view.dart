import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:page_flip/page_flip.dart';

import 'package:mobile/features/passport/pages/details_page.dart';
import 'package:mobile/features/passport/pages/identity_page.dart';
import 'package:mobile/features/passport/pages/stamp_page.dart';
import 'package:mobile/features/shared/models.dart';

/// A two-page passport spread. Two flavours:
/// • [VisitSpread] — left: country visa stamp page, right: visit details.
/// • [IdentitySpread] — left: multilingual welcome, right: holder ID card.
///
/// Implemented as a sealed-style abstract class so [PassportSpreadView] can
/// dispatch to the right left/right pages without leaking the variant union
/// outside this file.
abstract class BookSpread {
  const BookSpread();

  Widget buildLeft();
  Widget buildRight();
}

/// First inner spread — sits before any country stamps.
class IdentitySpread extends BookSpread {
  const IdentitySpread({required this.data});

  final IdentityCardData data;

  @override
  Widget buildLeft() => IdentityWelcomePage(data: data);

  @override
  Widget buildRight() => IdentityCardPage(data: data);
}

/// One country entry = stamp (left) + memory details (right), open-book spread.
class VisitSpread extends BookSpread {
  const VisitSpread({
    required this.visit,
    this.stampPhotoUrl,
    this.dishPhotoUrl,
    this.dishName,
  });

  final Visit visit;
  final String? stampPhotoUrl;
  final String? dishPhotoUrl;
  final String? dishName;

  @override
  Widget buildLeft() => StampPage(visit: visit, photoUrl: stampPhotoUrl);

  @override
  Widget buildRight() => DetailsPage(
        visit: visit,
        photoUrl: dishPhotoUrl,
        dishName: dishName,
      );
}

/// Backwards-compat alias for legacy call sites — equivalent to [VisitSpread].
typedef PassportSpread = VisitSpread;

/// Open-passport spreads with realistic page-curl flips ([page_flip] package).
class PassportSpreadView extends StatefulWidget {
  const PassportSpreadView({
    super.key,
    required this.spreads,
    this.initialSpreadIndex = 0,
    this.onSpreadChanged,
  });

  final List<BookSpread> spreads;
  final int initialSpreadIndex;
  final ValueChanged<int>? onSpreadChanged;

  @override
  State<PassportSpreadView> createState() => PassportSpreadViewState();
}

class PassportSpreadViewState extends State<PassportSpreadView> {
  final _flipKey = GlobalKey<PageFlipWidgetState>();

  /// Next spread — page turns from right to left.
  Future<void> flipTopDown() => flipForward();

  Future<void> flipForward() async {
    await _flipKey.currentState?.nextPage();
  }

  /// Previous spread.
  Future<void> flipBottomUp() => flipBack();

  Future<void> flipBack() async {
    await _flipKey.currentState?.previousPage();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spreads.isEmpty) {
      return const Center(
        child: Text('No entries yet', style: TextStyle(color: Colors.white54)),
      );
    }

    final initial = widget.initialSpreadIndex
        .clamp(0, widget.spreads.length - 1);

    return PageFlipWidget(
      key: _flipKey,
      backgroundColor: const Color(0xFFF6EDDC),
      initialIndex: initial,
      duration: const Duration(milliseconds: 580),
      cutoffForward: 0.72,
      cutoffPrevious: 0.12,
      onPageFlipped: (index) {
        HapticFeedback.lightImpact();
        widget.onSpreadChanged?.call(index);
      },
      children: [
        for (final spread in widget.spreads)
          _PassportSpreadSheet(spread: spread),
      ],
    );
  }
}

/// Static two-page spread (one flip “sheet” in the book).
class _PassportSpreadSheet extends StatelessWidget {
  const _PassportSpreadSheet({required this.spread});
  final BookSpread spread;

  static const _gutterW = 7.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final leftW = (size.width - _gutterW) / 2;
        final rightLeft = leftW + _gutterW;
        final rightW = size.width - rightLeft;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SpreadSlot(
                  width: leftW,
                  isLeft: true,
                  child: spread.buildLeft(),
                ),
                _PassportSpine(height: size.height),
                _SpreadSlot(
                  width: rightW,
                  isLeft: false,
                  child: spread.buildRight(),
                ),
              ],
            ),
            _PageEdge(
              size: size,
              leftW: leftW,
              rightLeft: rightLeft,
            ),
          ],
        );
      },
    );
  }
}

class _SpreadSlot extends StatelessWidget {
  const _SpreadSlot({
    required this.width,
    required this.isLeft,
    required this.child,
  });

  final double width;
  final bool isLeft;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6EDDC),
          boxShadow: isLeft
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(2, 0),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 8,
                    offset: const Offset(-3, 0),
                  ),
                ],
        ),
        child: ClipRect(child: child),
      ),
    );
  }
}

/// Vertical binding between left and right pages — leather spine with a
/// faint center thread highlight and dashed stitching.
class _PassportSpine extends StatelessWidget {
  const _PassportSpine({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PassportSpreadSheet._gutterW,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withOpacity(0.28),
              const Color(0xFF4A3120),
              const Color(0xFF2A1B0F),
              Colors.black.withOpacity(0.32),
            ],
            stops: const [0.0, 0.4, 0.6, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 6,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _SpineStitchPainter(),
        ),
      ),
    );
  }
}

/// Dashed thread stitching down the center of the spine.
class _SpineStitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final thread = Paint()
      ..color = const Color(0xFFD4A843).withOpacity(0.32)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    for (double y = 4; y < size.height; y += 9) {
      canvas.drawLine(Offset(cx, y), Offset(cx, y + 4.5), thread);
    }
  }

  @override
  bool shouldRepaint(covariant _SpineStitchPainter oldDelegate) => false;
}

class _PageEdge extends StatelessWidget {
  const _PageEdge({
    required this.size,
    required this.leftW,
    required this.rightLeft,
  });

  final Size size;
  final double leftW;
  final double rightLeft;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 5,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _EdgePainter(
            leftW: leftW,
            gutter: _PassportSpreadSheet._gutterW,
            rightLeft: rightLeft,
            height: size.height,
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.leftW,
    required this.gutter,
    required this.rightLeft,
    required this.height,
  });

  final double leftW;
  final double gutter;
  final double rightLeft;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFFE8D8C0), Color(0xFFB8A080), Color(0xFF8A7058)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, height));

    canvas.drawRect(Rect.fromLTWH(0, 0, leftW, height), paint);
    canvas.drawRect(
      Rect.fromLTWH(rightLeft, 0, size.width - rightLeft, height),
      paint,
    );

    final line = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(leftW, 0), Offset(leftW, height), line);
    canvas.drawLine(Offset(rightLeft, 0), Offset(rightLeft, height), line);
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.leftW != leftW || oldDelegate.rightLeft != rightLeft;
}
