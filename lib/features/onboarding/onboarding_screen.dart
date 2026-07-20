import 'dart:math' as math;
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'RECOVERY SD TOOL',
      subtitle: 'UNLOCK YOUR LOST DATA!',
      description: 'Giải pháp khôi phục dữ liệu chuyên nghiệp, nhanh chóng và tin cậy cho mọi thiết bị SD của bạn.',
      icon: Icons.memory_rounded,
      color: const Color(0xFF00E5FF), // Cyan Neon
    ),
    OnboardingData(
      title: 'FAST SCAN SYSTEM',
      subtitle: 'RECOVER WITH EASE',
      description: 'Thuật toán quét sâu giúp tìm lại ảnh, video và tài liệu bị mất trong tích tắc.',
      icon: Icons.radar_rounded,
      color: const Color(0xFF00B0FF), // Bright Blue
    ),
    OnboardingData(
      title: 'PREVIEW FILES',
      subtitle: 'SEE BEFORE RESTORE',
      description: 'Xem lại dữ liệu ngay trong quá trình quét để đảm bảo bạn chọn đúng những gì quan trọng nhất.',
      icon: Icons.visibility_rounded,
      color: const Color(0xFF76FF03), // Neon Green
    ),
    OnboardingData(
      title: 'SAFE & SECURE',
      subtitle: 'PROTECT YOUR MEMORY',
      description: 'Quy trình khôi phục an toàn tuyệt đối, đảm bảo không ghi đè hay làm hỏng dữ liệu gốc.',
      icon: Icons.security_rounded,
      color: const Color(0xFFFF3D00), // Neon Orange
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817), // Deep Navy Black
      body: Stack(
        children: [
          // Cyber Background with Circuit Lines
          Positioned.fill(
            child: CustomPaint(
              painter: CircuitPainter(
                color: _pages[_currentPage].color.withValues(alpha: 0.1),
                seed: _currentPage,
              ),
            ),
          ),
          
          // Glow background
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _pages[_currentPage].color.withValues(alpha: 0.1),
                    blurRadius: 100,
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
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return CyberOnboardingPage(data: _pages[index]);
            },
          ),
          
          // Skip button
          Positioned(
            top: 50,
            right: 30,
            child: TextButton(
              onPressed: () => _finishOnboarding(context),
              child: Text(
                'SKIP',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Bottom Navigation
          Positioned(
            bottom: 50,
            left: 40,
            right: 40,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => buildCyberDot(index),
                  ),
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () {
                    if (_currentPage == _pages.length - 1) {
                      _finishOnboarding(context);
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _pages[_currentPage].color,
                          _pages[_currentPage].color.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _pages[_currentPage].color.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'START RECOVERY' : 'NEXT STEP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
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

  void _finishOnboarding(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/home');
  }

  Widget buildCyberDot(int index) {
    bool isSelected = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 12),
      height: 4,
      width: isSelected ? 40 : 12,
      decoration: BoxDecoration(
        color: isSelected ? _pages[_currentPage].color : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
        boxShadow: isSelected ? [
          BoxShadow(
            color: _pages[_currentPage].color.withValues(alpha: 0.5),
            blurRadius: 10,
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
    final isFirstPage = data.title == 'RECOVERY SD TOOL';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing Icon/Logo Container
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: data.color.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
              ),
              // Radar pulse (simulated)
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: data.color.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
              ),
              // Main Icon or Logo
              if (isFirstPage)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    image: const DecorationImage(
                      image: AssetImage('assets/logo.jpeg'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: data.color.withValues(alpha: 0.5),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                )
              else
                Icon(
                  data.icon,
                  size: 100,
                  color: data.color,
                ),
              // Glowing shadow (only for icons)
              if (!isFirstPage)
                Icon(
                  data.icon,
                  size: 104,
                  color: data.color.withValues(alpha: 0.2),
                ),
            ],
          ),
          const SizedBox(height: 60),
          // Subtitle (Small & Technical)
          Text(
            data.subtitle,
            style: TextStyle(
              color: data.color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
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
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          // Description
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 120), // Bottom space
        ],
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
