import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/features/onboarding/bloc/onboarding_cubit.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<OnboardingData> _getPages(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      OnboardingData(
        title: l10n.onboardingTitle1,
        subtitle: l10n.onboardingSubtitle1,
        description: l10n.onboardingDesc1,
        icon: Icons.memory_rounded,
        color: AppTheme.cyberCyan,
      ),
      OnboardingData(
        title: l10n.onboardingTitle2,
        subtitle: l10n.onboardingSubtitle2,
        description: l10n.onboardingDesc2,
        icon: Icons.radar_rounded,
        color: AppTheme.cyberCyan,
      ),
      OnboardingData(
        title: l10n.onboardingTitle3,
        subtitle: l10n.onboardingSubtitle3,
        description: l10n.onboardingDesc3,
        icon: Icons.visibility_rounded,
        color: AppTheme.cyberCyan,
      ),
      OnboardingData(
        title: l10n.onboardingTitle4,
        subtitle: l10n.onboardingSubtitle4,
        description: l10n.onboardingDesc4,
        icon: Icons.security_rounded,
        color: AppTheme.cyberCyan,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.cyberDeepNavy,
      body: Stack(
        children: [
          // Cyber Background with Circuit Lines
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitPainter(
                color: AppTheme.cyberCyan.withValues(alpha: 0.05),
                seed: _currentPage,
              ),
            ),
          ),
          
          // Dynamic Glow background
          AnimatedPositioned(
            duration: const Duration(milliseconds: 800),
            top: -150,
            right: _currentPage.isEven ? -100 : 200,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyberCyan.withValues(alpha: 0.08),
                    blurRadius: 150,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: pages.length,
            itemBuilder: (context, index) {
              return CyberOnboardingPage(data: pages[index]);
            },
          ),
          
          // Skip button
          Positioned(
            top: 50,
            right: 40,
            child: TextButton(
              onPressed: () => _finishOnboarding(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.4),
              ),
              child: Text(
                l10n.skip,
                style: const TextStyle(
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // Bottom Navigation
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pages.length,
                    (index) => buildCyberDot(index),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 120),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        if (_currentPage == pages.length - 1) {
                          _finishOnboarding(context);
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.fastOutSlowIn,
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.cyberCyan,
                              AppTheme.cyberCyan.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.cyberCyan.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _currentPage == pages.length - 1 ? l10n.startRecovery : l10n.nextStep,
                            style: const TextStyle(
                              color: AppTheme.cyberDeepNavy,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _finishOnboarding(BuildContext context) async {
    final cubit = context.read<OnboardingCubit>();
    final navigator = Navigator.of(context);
    await cubit.completeOnboarding();
    if (mounted) {
      navigator.pushReplacementNamed('/home');
    }
  }

  Widget buildCyberDot(int index) {
    bool isSelected = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      margin: const EdgeInsets.only(right: 8),
      height: 6,
      width: isSelected ? 32 : 6,
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.cyberCyan : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
        boxShadow: isSelected ? [
          BoxShadow(
            color: AppTheme.cyberCyan.withValues(alpha: 0.4),
            blurRadius: 8,
          )
        ] : null,
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class CyberOnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const CyberOnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isFirstPage = data.icon == Icons.memory_rounded;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration Area with Glass Effect
          Stack(
            alignment: Alignment.center,
            children: [
              // Rotating decorative ring
              const _RotatingRing(),
              
              // Glass Container
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cyberCyan.withValues(alpha: 0.03),
                  border: Border.all(
                    color: AppTheme.cyberCyan.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
              ),
              
              // Main Icon or Logo
              if (isFirstPage)
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    image: const DecorationImage(
                      image: AssetImage('assets/logo.jpeg'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyberCyan.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: -10,
                      ),
                    ],
                  ),
                )
              else
                Icon(
                  data.icon,
                  size: 110,
                  color: AppTheme.cyberCyan,
                ),
                
              // Subtle glow for icons
              if (!isFirstPage)
                Icon(
                  data.icon,
                  size: 114,
                  color: AppTheme.cyberCyan.withValues(alpha: 0.15),
                ),
            ],
          ),
          const SizedBox(height: 60),
          // Content Card (Glassmorphism)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: AppTheme.cyberGlass,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.cyberCyan.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              children: [
                // Subtitle (Small & Technical)
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.cyberCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 12),
                // Main Title (Large & Bold)
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                // Description
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80), // Adjusted bottom space
        ],
      ),
    );
  }
}

class _RotatingRing extends StatefulWidget {
  const _RotatingRing();

  @override
  State<_RotatingRing> createState() => _RotatingRingState();
}

class _RotatingRingState extends State<_RotatingRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.cyberCyan.withValues(alpha: 0.05),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Stack(
          children: List.generate(4, (index) {
            final angle = (index * 90) * (math.pi / 180);
            return Positioned(
              left: 140 + 140 * math.cos(angle) - 4,
              top: 140 + 140 * math.sin(angle) - 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.cyberCyan,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class CircuitPainter extends CustomPainter {
  final Color color;
  final int seed;

  CircuitPainter({required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final random = math.Random(seed);
    
    // Draw some tech grid lines
    for (int i = 0; i < 10; i++) {
      double x = random.nextDouble() * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint..color = color.withValues(alpha: 0.05),
      );
    }

    // Draw circuit-like paths
    for (int i = 0; i < 8; i++) {
      final path = Path();
      double startX = random.nextDouble() * size.width;
      double startY = random.nextDouble() * size.height;
      
      path.moveTo(startX, startY);
      
      double currentX = startX;
      double currentY = startY;
      
      for (int j = 0; j < 4; j++) {
        bool horizontal = random.nextBool();
        double length = 50.0 + random.nextDouble() * 100.0;
        
        if (horizontal) {
          currentX += random.nextBool() ? length : -length;
        } else {
          currentY += random.nextBool() ? length : -length;
        }
        
        path.lineTo(currentX, currentY);
        
        // Draw a small joint circle
        canvas.drawCircle(
          Offset(currentX, currentY),
          2,
          paint..style = PaintingStyle.fill..color = color.withValues(alpha: 0.2),
        );
        paint.style = PaintingStyle.stroke; // reset
      }
      
      canvas.drawPath(path, paint..color = color.withValues(alpha: 0.15));
    }
  }

  @override
  bool shouldRepaint(covariant CircuitPainter oldDelegate) => oldDelegate.seed != seed;
}
