import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/app/gastro_theme_config.dart';
import 'package:mobile/app/gs_design.dart';
import 'package:mobile/features/social/data/social_models.dart';
import 'package:mobile/features/social/widgets/social_avatar.dart';

/// A single person row — passport-portrait avatar, display name, an optional
/// caption line, and a trailing action area (a follow pill, accept/decline
/// buttons, etc.). Tapping the row opens that person's public passport.
class SocialUserTile extends StatefulWidget {
  const SocialUserTile({
    super.key,
    required this.config,
    required this.user,
    required this.onTap,
    this.caption,
    this.trailing,
  });

  final GastroThemeConfig config;
  final SocialUser user;
  final VoidCallback onTap;

  /// Small line below the name — e.g. "Pending request" or a relationship hint.
  final String? caption;

  /// Trailing action widget (follow pill, accept/decline row, …).
  final Widget? trailing;

  @override
  State<SocialUserTile> createState() => _SocialUserTileState();
}

class _SocialUserTileState extends State<SocialUserTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final user = widget.user;

    return InkWell(
      onTap: widget.onTap,
      onHighlightChanged: (v) => setState(() => _pressed = v),
      borderRadius: BorderRadius.circular(GS.r16),
      splashColor: config.surfaceVariant,
      highlightColor: config.surfaceVariant.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: GS.s12, vertical: GS.s10),
        child: Row(
          children: [
            AnimatedScale(
              scale: _pressed ? 0.95 : 1.0,
              duration: GS.micro,
              curve: GS.smooth,
              child: SocialAvatar(
                config: config,
                initial: user.initial,
                avatarUrl: user.avatarUrl,
                size: 46,
              ),
            ),
            const SizedBox(width: GS.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: config.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.caption != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.caption!,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: config.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: GS.s10),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Accept / Decline button pair shown on pending incoming follow requests.
class RequestActions extends StatelessWidget {
  const RequestActions({
    super.key,
    required this.config,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  final GastroThemeConfig config;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: const EdgeInsets.all(GS.s6),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: config.accent,
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decline — quiet outlined circle.
        _RoundAction(
          icon: Icons.close_rounded,
          tooltip: 'Decline',
          background: Colors.transparent,
          foreground: config.onSurfaceVariant,
          border: config.outlineVariant,
          onTap: onDecline,
        ),
        const SizedBox(width: GS.s8),
        // Accept — filled accent circle.
        _RoundAction(
          icon: Icons.check_rounded,
          tooltip: 'Accept',
          background: config.accent,
          foreground: Colors.white,
          border: config.accent,
          onTap: onAccept,
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.border,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1.2),
            ),
            child: Icon(icon, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}
