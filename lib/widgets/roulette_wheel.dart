import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RouletteController {
  void Function(int winnerIndex)? _spinCallback;
  
  void spin(int winnerIndex) {
    _spinCallback?.call(winnerIndex);
  }
}

class RouletteWheel extends StatefulWidget {
  final List<String> names;
  final RouletteController controller;
  final Function(int winnerIndex) onSpinComplete;

  const RouletteWheel({
    super.key,
    required this.names,
    required this.controller,
    required this.onSpinComplete,
  });

  @override
  State<RouletteWheel> createState() => _RouletteWheelState();
}

class _RouletteWheelState extends State<RouletteWheel> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  
  double _currentWheelAngle = 0.0;
  double _currentBallAngle = 0.0;
  double _currentBallRadius = 85.0;
  
  int _winnerIndex = 0;
  bool _isSpinning = false;

  // Animation target values
  double _targetWheelAngle = 0.0;
  double _targetBallAngle = 0.0;
  final double _outerBallRadius = 85.0;
  final double _innerBallRadius = 60.0;

  @override
  void initState() {
    super.initState();
    widget.controller._spinCallback = _startSpin;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.decelerate,
    )..addListener(_updatePhysics);

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isSpinning = false;
        });
        widget.onSpinComplete(_winnerIndex);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startSpin(int winnerIndex) {
    if (_isSpinning) return;

    _winnerIndex = winnerIndex;
    _isSpinning = true;

    final int numSectors = widget.names.length;
    final double sectorWidth = 2 * pi / numSectors;
    
    // We want the ball to land at the top pointer (-pi / 2) at the end.
    // The relative angle of the winning sector is (winnerIndex * sectorWidth + sectorWidth / 2).
    // Final absolute ball angle is at the top pointer: -pi / 2
    // Relative position on wheel: ballAngle - wheelAngle = sectorCenter
    // Thus: -pi / 2 - wheelAngle = winnerIndex * sectorWidth + sectorWidth / 2
    // wheelAngle = -pi / 2 - (winnerIndex * sectorWidth + sectorWidth / 2)
    // To make it spin multiple times clockwise, add rotations (e.g. 5 full spins):
    const int wheelSpins = 6;
    _targetWheelAngle = (wheelSpins * 2 * pi) - (winnerIndex * sectorWidth + sectorWidth / 2) - (pi / 2);
    
    // The ball spins counter-clockwise (opposite direction) multiple times and ends at -pi / 2
    const int ballSpins = 4;
    _targetBallAngle = -(ballSpins * 2 * pi) - (pi / 2);

    _animationController.reset();
    _animationController.forward();
  }

  void _updatePhysics() {
    final t = _animation.value;
    
    setState(() {
      // Interpolate angles
      _currentWheelAngle = _targetWheelAngle * t;
      _currentBallAngle = _targetBallAngle * t;

      // Ball spiral physics:
      // - First 40% of animation: ball rolls along the outer rim
      // - 40% to 85% of animation: ball spirals inwards towards the sectors
      // - 85% to 100%: ball locks into the sector (rotates in sync with the wheel)
      if (t < 0.4) {
        _currentBallRadius = _outerBallRadius;
      } else if (t < 0.85) {
        final double spiralT = (t - 0.4) / 0.45;
        _currentBallRadius = _outerBallRadius - (_outerBallRadius - _innerBallRadius) * spiralT;
      } else {
        _currentBallRadius = _innerBallRadius;
        // In the final phase, lock the ball to the winning sector's center angle
        final double sectorWidth = 2 * pi / widget.names.length;
        final double winningSectorAngleOnWheel = _winnerIndex * sectorWidth + sectorWidth / 2;
        _currentBallAngle = _currentWheelAngle + winningSectorAngleOnWheel;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.1),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. The custom painted roulette board
          Positioned.fill(
            child: CustomPaint(
              painter: _RoulettePainter(
                names: widget.names,
                wheelAngle: _currentWheelAngle,
                ballAngle: _currentBallAngle,
                ballRadius: _currentBallRadius,
                isSpinning: _isSpinning,
              ),
            ),
          ),
          // 2. Center hub / gold cap
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.bgSurfaceLight,
              border: Border.all(color: AppTheme.secondary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondary.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.stars,
              size: 16,
              color: AppTheme.secondary,
            ),
          ),
          // 3. Top Pointer (where the winner is indicated)
          Positioned(
            top: 2,
            child: CustomPaint(
              size: const Size(20, 20),
              painter: _PointerPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoulettePainter extends CustomPainter {
  final List<String> names;
  final double wheelAngle;
  final double ballAngle;
  final double ballRadius;
  final bool isSpinning;

  _RoulettePainter({
    required this.names,
    required this.wheelAngle,
    required this.ballAngle,
    required this.ballRadius,
    required this.isSpinning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;
    
    // Draw outer wooden/space rim
    final rimPaint = Paint()
      ..color = AppTheme.bgSurfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(center, radius + 5, rimPaint);

    final borderPaint = Paint()
      ..color = AppTheme.glassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius + 12, borderPaint);

    final int n = names.length;
    final double sweepAngle = 2 * pi / n;

    // Draw slices
    for (int i = 0; i < n; i++) {
      final startAngle = i * sweepAngle + wheelAngle;
      
      // Alternate sector colors using auroral palette
      final sectorPaint = Paint()
        ..color = (i % 2 == 0) ? AppTheme.bgSurface : const Color(0xFF141328)
        ..style = PaintingStyle.fill;
        
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        sectorPaint,
      );

      // Draw sector divider lines
      final dividerPaint = Paint()
        ..color = AppTheme.glassBorder.withOpacity(0.1)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(startAngle),
          center.dy + radius * sin(startAngle),
        ),
        dividerPaint,
      );

      // Write Names inside the sectors
      canvas.save();
      // Translate to center and rotate to point along the center of the sector
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + sweepAngle / 2);

      // Draw text painter
      final textStyle = TextStyle(
        color: AppTheme.textPrimary.withOpacity(0.9),
        fontSize: n > 8 ? 9 : 11,
        fontWeight: FontWeight.bold,
      );
      final textSpan = TextSpan(
        text: names[i].length > 8 ? '${names[i].substring(0, 7)}..' : names[i],
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Draw text horizontally starting from inner radius towards the rim
      textPainter.paint(
        canvas,
        Offset(radius * 0.32, -textPainter.height / 2),
      );
      
      canvas.restore();
    }

    // Draw the ball inside the roulette
    final ballCenter = Offset(
      center.dx + ballRadius * cos(ballAngle),
      center.dy + ballRadius * sin(ballAngle),
    );

    final ballShadow = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(ballCenter, 7.5, ballShadow);

    final ballPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(ballCenter, 6.0, ballPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // Glowing outline
    final outlinePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
