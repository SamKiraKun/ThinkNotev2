import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/accessibility_utils.dart';

class AnimatedTapScaleStateData {
  const AnimatedTapScaleStateData({
    required this.isHovered,
    required this.isPressed,
    required this.isFocused,
    required this.isDisabled,
  });

  final bool isHovered;
  final bool isPressed;
  final bool isFocused;
  final bool isDisabled;

  double scaleFor({
    required bool reducedMotion,
    required double tapScale,
    required double hoverScale,
  }) {
    if (reducedMotion || isDisabled) {
      return 1;
    }

    if (isPressed) {
      return tapScale;
    }

    if (isHovered) {
      return hoverScale;
    }

    return 1;
  }
}

class AnimatedTapScale extends StatefulWidget {
  final Widget Function(BuildContext context, AnimatedTapScaleStateData state)
      builder;
  final VoidCallback? onTap;
  final double tapScale;
  final double hoverScale;
  final bool disabled;

  const AnimatedTapScale({
    super.key,
    required this.builder,
    this.onTap,
    this.tapScale = 0.96,
    this.hoverScale = 1.02,
    this.disabled = false,
  });

  @override
  State<AnimatedTapScale> createState() => _AnimatedTapScaleState();
}

class _AnimatedTapScaleState extends State<AnimatedTapScale> {
  bool _isHovering = false;
  bool _isTapped = false;
  bool _isFocused = false;

  void _onHover(bool isHovering) {
    if (widget.disabled) return;
    setState(() => _isHovering = isHovering);
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.disabled) return;
    setState(() => _isTapped = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.disabled) return;
    setState(() => _isTapped = false);
  }

  void _onTapCancel() {
    if (widget.disabled) return;
    setState(() => _isTapped = false);
  }

  void _onShowFocusHighlight(bool isFocused) {
    if (widget.disabled) {
      return;
    }
    setState(() => _isFocused = isFocused);
  }

  @override
  Widget build(BuildContext context) {
    final state = AnimatedTapScaleStateData(
      isHovered: _isHovering,
      isPressed: _isTapped,
      isFocused: _isFocused,
      isDisabled: widget.disabled,
    );
    final reducedMotion = AccessibilityUtils.reducedMotionOf(context);
    final duration =
        reducedMotion ? Duration.zero : AppConstants.interactiveDuration;
    final scale = state.scaleFor(
      reducedMotion: reducedMotion,
      tapScale: widget.tapScale,
      hoverScale: widget.hoverScale,
    );

    return FocusableActionDetector(
      enabled: !widget.disabled,
      mouseCursor:
          widget.disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onShowHoverHighlight: _onHover,
      onShowFocusHighlight: _onShowFocusHighlight,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            if (!widget.disabled) {
              widget.onTap?.call();
            }
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.disabled ? null : widget.onTap,
        onTapDown: widget.disabled ? null : _onTapDown,
        onTapUp: widget.disabled ? null : _onTapUp,
        onTapCancel: widget.disabled ? null : _onTapCancel,
        child: AnimatedScale(
          scale: scale,
          duration: duration,
          curve: AppConstants.interactiveCurve,
          child: AnimatedOpacity(
            opacity: widget.disabled ? 0.55 : 1,
            duration: duration,
            curve: AppConstants.interactiveCurve,
            child: widget.builder(context, state),
          ),
        ),
      ),
    );
  }
}
