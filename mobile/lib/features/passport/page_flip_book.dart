import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A realistic vertical-flip passport book. Pages turn from the **bottom edge
/// up** (like a real passport), with a curved peel, shadow on the underlying
/// page, and inertia from drag velocity.
class PageFlipBook extends StatefulWidget {
  const PageFlipBook({
    super.key,
    required this.pages,
    this.initialIndex = 0,
    this.onPageChanged,
  });

  final List<Widget> pages;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;

  @override
  State<PageFlipBook> createState() => PageFlipBookState();
}

class PageFlipBookState extends State<PageFlipBook>
    with SingleTickerProviderStateMixin {
  late int _topIndex;
  late final AnimationController _ctrl;

  /// 0.0 — page rests flat, 1.0 — page fully peeled away from bottom→top.
  double _progress = 0.0;
  bool _isDragging = false;

  /// 1.0 = flipping forward (next), -1.0 = flipping backward (previous).
  double _direction = 1.0;

  @override
  void initState() {
    super.initState();
    _topIndex = widget.initialIndex.clamp(0, widget.pages.length - 1);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addListener(() => setState(() => _progress = _ctrl.value));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> next() async {
    if (_topIndex >= widget.pages.length - 1 || _ctrl.isAnimating) return;
    _direction = 1.0;
    _ctrl.value = 0.0;
    await _ctrl.animateTo(
      1.0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
    setState(() {
      _topIndex++;
      _progress = 0.0;
    });
    _ctrl.value = 0.0;
    widget.onPageChanged?.call(_topIndex);
  }

  Future<void> previous() async {
    if (_topIndex <= 0 || _ctrl.isAnimating) return;
    _direction = -1.0;
    setState(() {
      _topIndex--;
    });
    _ctrl.value = 1.0;
    await _ctrl.animateBack(
      0.0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
    widget.onPageChanged?.call(_topIndex);
  }

  void _onPanStart(DragStartDetails d, Size size) {
    if (_ctrl.isAnimating) return;
    final fromBottom = d.localPosition.dy > size.height / 2;
    _direction = fromBottom ? 1.0 : -1.0;

    if (_direction < 0) {
      if (_topIndex <= 0) return;
      setState(() {
        _topIndex--;
        _progress = 1.0;
      });
    } else {
      if (_topIndex >= widget.pages.length - 1) return;
      setState(() => _progress = 0.0);
    }
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (!_isDragging) return;
    final delta = -d.delta.dy / size.height;
    final newProgress = (_progress + delta).clamp(0.0, 1.0);
    setState(() => _progress = newProgress);
  }

  void _onPanEnd(DragEndDetails d, Size size) async {
    if (!_isDragging) return;
    _isDragging = false;
    final vel = d.velocity.pixelsPerSecond.dy;
    final shouldComplete = _direction > 0
        ? (_progress > 0.40 || vel < -400)
        : (_progress < 0.60 || vel > 400);

    _ctrl.value = _progress;
    if (shouldComplete) {
      if (_direction > 0) {
        await _ctrl.animateTo(
          1.0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
        if (!mounted) return;
        setState(() {
          _topIndex++;
          _progress = 0.0;
        });
        _ctrl.value = 0.0;
        widget.onPageChanged?.call(_topIndex);
      } else {
        await _ctrl.animateBack(
          0.0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
        if (!mounted) return;
        widget.onPageChanged?.call(_topIndex);
      }
    } else {
      if (_direction > 0) {
        await _ctrl.animateBack(
          0.0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      } else {
        await _ctrl.animateTo(
          1.0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
        if (!mounted) return;
        setState(() {
          _topIndex++;
          _progress = 0.0;
        });
        _ctrl.value = 0.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          onVerticalDragStart: (d) => _onPanStart(d, size),
          onVerticalDragUpdate: (d) => _onPanUpdate(d, size),
          onVerticalDragEnd: (d) => _onPanEnd(d, size),
          onTapUp: (d) {
            if (_ctrl.isAnimating || _isDragging) return;
            if (d.localPosition.dy > size.height * 0.72) {
              next();
            } else if (d.localPosition.dy < size.height * 0.28) {
              previous();
            }
          },
          child: Stack(
            children: [
              _buildBookBack(),
              if (_topIndex + 1 < widget.pages.length)
                Positioned.fill(child: widget.pages[_topIndex + 1]),
              Positioned.fill(
                child: _VerticallyCurledPage(
                  progress: _progress,
                  child: widget.pages[_topIndex],
                ),
              ),
              _buildBindingShadow(),
              _buildOuterEdge(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookBack() {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A2418), Color(0xFF1F140C)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  /// A subtle shadow along the top edge (binding) like a real passport's
  /// stitched spine.
  Widget _buildBindingShadow() {
    return IgnorePointer(
      child: Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.30),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOuterEdge() {
    return IgnorePointer(
      child: Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.black.withOpacity(0.12),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticallyCurledPage extends StatelessWidget {
  const _VerticallyCurledPage({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.001) {
      return child;
    }

    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final curlY = size.height * (1.0 - progress);

      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          ClipPath(
            clipper: _StaticTopClipper(curlY: curlY),
            child: SizedBox.expand(child: child),
          ),
          if (progress > 0.02)
            Positioned.fill(
              child: CustomPaint(
                painter: _CurlShadowPainter(
                  progress: progress,
                  curlY: curlY,
                ),
              ),
            ),
          if (progress > 0.02)
            ClipPath(
              clipper: _CurledRegionClipper(curlY: curlY),
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: _curlTransform(progress, size),
                child: Stack(
                  children: [
                    Positioned.fill(child: child),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.24 * progress),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  Matrix4 _curlTransform(double p, Size size) {
    // Flip the bottom half of the page upward, mirroring around X axis.
    final flip = Matrix4.identity()
      ..setEntry(3, 2, 0.0010)
      ..rotateX(math.pi);
    final shift = Matrix4.identity()
      ..translate(0.0, -size.height * (1 - p), 0.0);
    final tilt = Matrix4.identity()..rotateZ(0.025 * p);
    return shift.multiplied(tilt).multiplied(flip);
  }
}

class _StaticTopClipper extends CustomClipper<Path> {
  _StaticTopClipper({required this.curlY});
  final double curlY;

  @override
  Path getClip(Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, curlY)
      ..lineTo(0, curlY)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(covariant _StaticTopClipper oldDelegate) =>
      oldDelegate.curlY != curlY;
}

class _CurledRegionClipper extends CustomClipper<Path> {
  _CurledRegionClipper({required this.curlY});
  final double curlY;

  @override
  Path getClip(Size size) {
    final p = Path()
      ..moveTo(0, curlY)
      ..lineTo(size.width, curlY)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(covariant _CurledRegionClipper oldDelegate) =>
      oldDelegate.curlY != curlY;
}

class _CurlShadowPainter extends CustomPainter {
  _CurlShadowPainter({required this.progress, required this.curlY});
  final double progress;
  final double curlY;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.black.withOpacity(0.32 * progress),
          Colors.black.withOpacity(0.12 * progress),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(
        Rect.fromLTWH(0, curlY - 32, size.width, 32),
      );
    canvas.drawRect(
      Rect.fromLTWH(0, curlY - 32, size.width, 32),
      shadow,
    );

    final foldLine = Paint()
      ..color = Colors.black.withOpacity(0.42 * progress)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, curlY), Offset(size.width, curlY), foldLine);
  }

  @override
  bool shouldRepaint(covariant _CurlShadowPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.curlY != curlY;
}
