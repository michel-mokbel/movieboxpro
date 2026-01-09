import 'package:flutter/material.dart';
import 'package:moviemagicbox/utils/bento_theme.dart';

class AiLoader extends StatefulWidget {
  final String? label;
  final double size;

  const AiLoader({
    super.key,
    this.label,
    this.size = 58,
  });

  @override
  State<AiLoader> createState() => _AiLoaderState();
}

class _AiLoaderState extends State<AiLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  late Animation<double> _glow;
  late List<Animation<double>> _dots;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulse = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.15, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _dots = List.generate(3, (index) {
      final start = index * 0.2;
      return Tween<double>(begin: 0.6, end: 1.1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, start + 0.6, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size * 1.4,
          height: widget.size * 1.4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _glow,
                builder: (context, child) {
                  return Opacity(
                    opacity: _glow.value,
                    child: Transform.scale(
                      scale: 1.1 + _glow.value * 0.4,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: BentoTheme.accent.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: BentoTheme.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: BentoTheme.accent.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_dots.length, (index) {
            return AnimatedBuilder(
              animation: _dots[index],
              builder: (context, child) {
                final value = _dots[index].value;
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: 0.4 + (value - 0.6) * 0.8,
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: EdgeInsets.only(right: index == _dots.length - 1 ? 0 : 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.label!,
            style: BentoTheme.caption.copyWith(color: BentoTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}
