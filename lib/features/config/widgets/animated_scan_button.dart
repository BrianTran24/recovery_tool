import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AnimatedScanButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  const AnimatedScanButton({
    super.key,
    required this.onTap,
    required this.label,
  });

  @override
  State<AnimatedScanButton> createState() => _AnimatedScanButtonState();
}

class _AnimatedScanButtonState extends State<AnimatedScanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Smooth Ripple waves
            ...List.generate(2, (index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final progress = (_controller.value + (index / 2)) % 1.0;
                  return Container(
                    width: 100 + (120 * progress),
                    height: 100 + (120 * progress),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.cyberCyan.withValues(
                          alpha: (1.0 - progress) * 0.2,
                        ),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              );
            }),

            // Breathing & Tap Scale Effect
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final breatheScale = 1.0 + (0.05 * (1.0 - (0.5 - _controller.value).abs() * 2));
                final combinedScale = (_isPressed ? 0.92 : 1.0) * breatheScale;
                
                return Transform.scale(
                  scale: combinedScale,
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.cyberCyan.withValues(alpha: 0.2),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),

                  // Main Button Body
                  Container(
                    width: 124,
                    height: 124,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.cyberCyan,
                          AppTheme.cyberCyan.withValues(alpha: 0.9),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: Offset.zero,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF001219), // Restored high-contrast dark color
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: Colors.black12,
                              offset: Offset(0, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
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
