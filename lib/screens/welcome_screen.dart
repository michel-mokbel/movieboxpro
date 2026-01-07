import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moviemagicbox/screens/main_screen.dart';
import 'package:moviemagicbox/utils/ios_theme.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _scrollController;
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _buttonScale;
  
  // Using the movie posters for the background wall
  final List<String> _posterAssets = [
    'lib/assets/images/avengers.jpg',
    'lib/assets/images/dark_knight.jpg',
    'lib/assets/images/doctor_strange.jpg',
    'lib/assets/images/inception.jpg',
    'lib/assets/images/interstellar.jpg',
    'lib/assets/images/joker.jpg',
    'lib/assets/images/black.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _requestAttIfNeeded();
    
    // Infinite scroll animation
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Button pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // Floating cards animation
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _buttonScale = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _requestAttIfNeeded() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      // Default to true if not fetched yet or key doesn't exist to be safe, 
      // or false if you prefer not to annoy user. 
      // Assuming 'false' as default for now to match typical flow.
      final showAtt = remoteConfig.getBool('show_att');
      
      if (showAtt) {
        await Future.delayed(const Duration(seconds: 1));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      print('Failed to request tracking authorization: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Angled Moving Wall of Posters
          Positioned.fill(
            child: Transform.rotate(
              angle: -10 * math.pi / 180, // Tilt -10 degrees
              child: Transform.scale(
                scale: 1.5, // Scale up to cover edges after rotation
                child: Row(
                  children: [
                    Expanded(
                      child: _buildInfiniteColumn(
                        speed: 1.0, 
                        isReverse: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInfiniteColumn(
                        speed: 1.5, 
                        isReverse: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInfiniteColumn(
                        speed: 0.8, 
                        isReverse: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Heavy Vignette / Gradient Overlay
          // This ensures the text is legible and the background is just ambiance
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.95),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // const Spacer(),
                  
                  // // Unique "Floating Deck" of Feature Cards (First, Second, Third)
                  // // This serves as a visual hook "thinking outside the box"
                  // SizedBox(
                  //   height: 320,
                  //   width: double.infinity,
                  //   child: AnimatedBuilder(
                  //     animation: _floatController,
                  //     builder: (context, child) {
                  //       return Stack(
                  //         alignment: Alignment.center,
                  //         children: [
                  //           // Back card (Third)
                  //           _buildFloatingCard(
                  //             'lib/assets/images/Third.png',
                  //             angle: -0.15,
                  //             offset: Offset(-60, -20 + math.sin(_floatController.value * math.pi) * 10),
                  //             scale: 0.85,
                  //             opacity: 0.6,
                  //           ),
                  //           // Middle card (Second)
                  //           _buildFloatingCard(
                  //             'lib/assets/images/Second.png',
                  //             angle: 0.1,
                  //             offset: Offset(60, -10 + math.cos(_floatController.value * math.pi) * 10),
                  //             scale: 0.9,
                  //             opacity: 0.8,
                  //           ),
                  //           // Front card (First)
                  //           _buildFloatingCard(
                  //             'lib/assets/images/First.png',
                  //             angle: 0,
                  //             offset: Offset(0, 20 + math.sin(_floatController.value * math.pi) * 5),
                  //             scale: 1.0,
                  //             opacity: 1.0,
                  //             isFront: true,
                  //           ),
                  //         ],
                  //       );
                  //     },
                  //   ),
                  // ),
                  
                  // const Spacer(),

                  // Typography
                  Text(
                    "Cinema\nReimagined",
                    textAlign: TextAlign.center,
                    style: IOSTheme.largeTitle.copyWith(
                      fontSize: 48,
                      height: 1.0,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: IOSTheme.systemBlue.withOpacity(0.8),
                          blurRadius: 30,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Unlock the movies. Experience entertainment in a whole new dimension.",
                    textAlign: TextAlign.center,
                    style: IOSTheme.body.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      height: 1.4,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Action Button
                  ScaleTransition(
                    scale: _buttonScale,
                      child: Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [IOSTheme.systemBlue, Color(0xFF0055D0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: IOSTheme.systemBlue.withOpacity(0.6),
                              blurRadius: 25,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(30),
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          Navigator.pushReplacement(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              transitionDuration: const Duration(milliseconds: 800),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Start Watching",
                              style: IOSTheme.title3.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(CupertinoIcons.arrow_right_circle_fill, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfiniteColumn({
    required double speed,
    required bool isReverse,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _scrollController,
          builder: (context, child) {
            final double scrollValue = _scrollController.value * speed;
            // Height (200) + Margin (16) = 216
            final double itemHeight = 216.0;
            final double totalHeight = _posterAssets.length * itemHeight;
            
            // Calculate current offset
            final double currentScroll = (scrollValue % 1.0) * totalHeight;
            
            double yOffset;
            if (isReverse) {
              yOffset = -totalHeight + currentScroll;
            } else {
              yOffset = -currentScroll;
            }
            
            // KEY FIX: OverflowBox allows the child to be larger than the parent
            // preventing RenderFlex overflow errors.
            return OverflowBox(
              minHeight: 0,
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, yOffset),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // shrink wrap vertically
                  children: [
                    // 3 sets to ensure seamless loop
                    ..._buildPosterList(),
                    ..._buildPosterList(),
                    ..._buildPosterList(),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }

  List<Widget> _buildPosterList() {
    return _posterAssets.map((path) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: AssetImage(path),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // Overlay to dim background posters
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withOpacity(0.3),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFloatingCard(
    String assetPath, {
    required double angle,
    required Offset offset,
    required double scale,
    required double opacity,
    bool isFront = false,
  }) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 200,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.black, // Fallback
              boxShadow: [
                BoxShadow(
                  color: isFront 
                      ? IOSTheme.systemBlue.withOpacity(0.4) 
                      : Colors.black.withOpacity(0.5),
                  blurRadius: isFront ? 30 : 20,
                  spreadRadius: isFront ? 2 : 0,
                  offset: const Offset(0, 10),
                ),
              ],
              image: DecorationImage(
                image: AssetImage(assetPath),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(1.0 - opacity),
                  BlendMode.darken,
                ),
              ),
              border: isFront 
                  ? Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)
                  : null,
            ),
            // Glass reflection effect for front card
            child: isFront 
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0), // Just for effect hook if needed later
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.white.withOpacity(0.05),
                            ],
                            stops: const [0.0, 0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
