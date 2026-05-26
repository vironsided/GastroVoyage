import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Floating Sims-style plumbob with a subtle bobbing animation and rotation.
/// Use over the avatar in Guys-mode dashboard to indicate "active player".
class AnimatedPlumbob extends StatefulWidget {
  const AnimatedPlumbob({
    super.key,
    this.size = 36,
    this.bobAmplitude = 4,
    this.period = const Duration(seconds: 3),
  });

  final double size;
  final double bobAmplitude;
  final Duration period;

  @override
  State<AnimatedPlumbob> createState() => _AnimatedPlumbobState();
}

class _AnimatedPlumbobState extends State<AnimatedPlumbob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value * 2 * math.pi;
        final dy = math.sin(t) * widget.bobAmplitude;
        // Very subtle tilt — sells the floating idea
        final rot = math.sin(t * 0.5) * 0.05;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: rot, child: child),
        );
      },
      child: Image.asset(
        'assets/components/guys/plumbob.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      ),
    );
  }
}
