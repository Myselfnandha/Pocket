import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WavingHandEmoji extends StatefulWidget {
  final double fontSize;
  const WavingHandEmoji({super.key, this.fontSize = 20});

  @override
  State<WavingHandEmoji> createState() => _WavingHandEmojiState();
}

class _WavingHandEmojiState extends State<WavingHandEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _waveAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.38).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.38, end: -0.32).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.32, end: 0.28).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.28, end: -0.22).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.22, end: 0.12).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.12, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
    ]).animate(_controller);

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_controller);

    // Trigger waving & glow on initial open
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _controller.forward(from: 0.0);
      }
    });
  }

  void _triggerWave() {
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerWave,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final glowVal = _glowAnimation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Radial Warm Golden & Emerald Glow Halo
              if (glowVal > 0.01)
                Container(
                  width: widget.fontSize * 1.5,
                  height: widget.fontSize * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.55 * glowVal),
                        blurRadius: 16 * glowVal,
                        spreadRadius: 4 * glowVal,
                      ),
                      BoxShadow(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.35 * glowVal),
                        blurRadius: 12 * glowVal,
                        spreadRadius: 2 * glowVal,
                      ),
                    ],
                  ),
                ),
              // Tilting Hand Emoji
              Transform(
                alignment: Alignment.bottomRight,
                transform: Matrix4.rotationZ(_waveAnimation.value),
                child: Text(
                  '👋',
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    shadows: glowVal > 0.01
                        ? [
                            Shadow(
                              color: const Color(0xFFFFD54F).withValues(alpha: 0.8 * glowVal),
                              blurRadius: 10 * glowVal,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
