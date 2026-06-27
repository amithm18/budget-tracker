import 'dart:math';
import 'package:flutter/material.dart';

// Helper to convert hex string to Flutter Color
Color _hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 3) {
    hex = hex.split('').map((c) => c + c).join('');
  }
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  return Color(int.parse(hex, radix: 16));
}

enum StarType { standard, twinkle, flare }

class Particle3D {
  // 3D coordinate space positions
  double x;
  double y;
  double z;
  
  // Random variables used as parameters in shader calculations
  double rx;
  double ry;
  double rz;
  double rw;
  
  Color color;
  StarType starType;

  Particle3D({
    required this.x,
    required this.y,
    required this.z,
    required this.rx,
    required this.ry,
    required this.rz,
    required this.rw,
    required this.color,
    required this.starType,
  });
}

class ShootingStar {
  double startX;
  double startY;
  double endX;
  double endY;
  double progress; // 0.0 to 1.0
  double speed;
  double size;

  ShootingStar({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.progress,
    required this.speed,
    required this.size,
  });
}

class AntigravityBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final double particleSpread;
  final double speed;
  final List<String> particleColors;
  final bool moveParticlesOnHover;
  final double particleHoverFactor;
  final bool alphaParticles;
  final double particleBaseSize;
  final double sizeRandomness;
  final double cameraDistance;
  final bool disableRotation;
  final double pixelRatio;

  const AntigravityBackground({
    super.key,
    required this.child,
    this.particleCount = 120, // Clean, performance-friendly star count
    this.particleSpread = 15.0,
    this.speed = 0.05,
    this.particleColors = const ['#A78BFA', '#06B6D4', '#FFFFFF', '#6366F1'], // Space colors
    this.moveParticlesOnHover = true,
    this.particleHoverFactor = 1.0,
    this.alphaParticles = true,
    this.particleBaseSize = 30.0,
    this.sizeRandomness = 0.8,
    this.cameraDistance = 25.0,
    this.disableRotation = false,
    this.pixelRatio = 1.0,
  });

  @override
  State<AntigravityBackground> createState() => _AntigravityBackgroundState();
}

class _AntigravityBackgroundState extends State<AntigravityBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle3D> _particles = [];
  final List<ShootingStar> _shootingStars = [];
  final Random _random = Random();
  
  // Mouse interaction state tracking
  Offset _targetMouse = Offset.zero;
  double _smoothMouseX = 0.0;
  double _smoothMouseY = 0.0;
  double _elapsedTime = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isEmpty) {
      _initParticles();
    }
  }

  void _initParticles() {
    final colors = widget.particleColors.map(_hexToColor).toList();
    
    for (int i = 0; i < widget.particleCount; i++) {
      // Generate uniform spherical points (x^2 + y^2 + z^2 <= 1)
      double x, y, z, len;
      do {
        x = _random.nextDouble() * 2.0 - 1.0;
        y = _random.nextDouble() * 2.0 - 1.0;
        z = _random.nextDouble() * 2.0 - 1.0;
        len = x * x + y * y + z * z;
      } while (len > 1.0 || len == 0.0);

      // Distribute points radially inside sphere
      final r = cuberoot(_random.nextDouble());
      
      // Determine star type distribution
      final randVal = _random.nextDouble();
      StarType starType;
      if (randVal < 0.70) {
        starType = StarType.standard;
      } else if (randVal < 0.90) {
        starType = StarType.twinkle;
      } else {
        starType = StarType.flare;
      }

      _particles.add(Particle3D(
        x: x * r,
        y: y * r,
        z: z * r,
        rx: _random.nextDouble(),
        ry: _random.nextDouble(),
        rz: _random.nextDouble(),
        rw: _random.nextDouble(),
        color: colors[_random.nextInt(colors.length)],
        starType: starType,
      ));
    }
  }

  double cuberoot(double x) {
    return pow(x, 1.0 / 3.0).toDouble();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        if (widget.moveParticlesOnHover) {
          final size = MediaQuery.of(context).size;
          // Normalize mouse coordinates to [-1, 1]
          final mx = (event.localPosition.dx / size.width) * 2 - 1;
          final my = -((event.localPosition.dy / size.height) * 2 - 1);
          _targetMouse = Offset(mx, my);
        }
      },
      onExit: (_) {
        _targetMouse = Offset.zero;
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          _updatePhysics(MediaQuery.of(context).size);
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: Particle3DPainter(
                    particles: _particles,
                    shootingStars: _shootingStars,
                    elapsedTime: _elapsedTime,
                    spread: widget.particleSpread,
                    baseSize: widget.particleBaseSize,
                    sizeRandomness: widget.sizeRandomness,
                    cameraDistance: widget.cameraDistance,
                    disableRotation: widget.disableRotation,
                    alphaParticles: widget.alphaParticles,
                    pixelRatio: widget.pixelRatio,
                    hoverOffsetX: _smoothMouseX * widget.particleHoverFactor * 6.0,
                    hoverOffsetY: -_smoothMouseY * widget.particleHoverFactor * 6.0,
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: widget.child,
      ),
    );
  }

  void _updatePhysics(Size size) {
    // Increment time delta based on speed multiplier
    _elapsedTime += widget.speed * 0.16; // Approx tick rate
    
    // Lerp hover mouse tracking coordinate to create smooth movement delays
    _smoothMouseX += (_targetMouse.dx - _smoothMouseX) * 0.05;
    _smoothMouseY += (_targetMouse.dy - _smoothMouseY) * 0.05;

    // Update active shooting stars
    for (int i = _shootingStars.length - 1; i >= 0; i--) {
      final s = _shootingStars[i];
      s.progress += s.speed;
      if (s.progress >= 1.0) {
        _shootingStars.removeAt(i);
      }
    }

    // Occasional shooting star spawning
    if (size.width > 0 && size.height > 0) {
      if (_random.nextDouble() < 0.005 && _shootingStars.length < 3) {
        final startX = _random.nextDouble() * size.width;
        final startY = _random.nextDouble() * (size.height * 0.4); // Top 40% of screen
        final angle = (35 + _random.nextDouble() * 20) * pi / 180; // Fly down-left at 35-55 deg
        final length = 200.0 + _random.nextDouble() * 250.0;

        _shootingStars.add(ShootingStar(
          startX: startX,
          startY: startY,
          endX: startX - cos(angle) * length,
          endY: startY + sin(angle) * length,
          progress: 0.0,
          speed: 0.015 + _random.nextDouble() * 0.02,
          size: 1.2 + _random.nextDouble() * 1.5,
        ));
      }
    }
  }
}

class Particle3DPainter extends CustomPainter {
  final List<Particle3D> particles;
  final List<ShootingStar> shootingStars;
  final double elapsedTime;
  final double spread;
  final double baseSize;
  final double sizeRandomness;
  final double cameraDistance;
  final bool disableRotation;
  final bool alphaParticles;
  final double pixelRatio;
  final double hoverOffsetX;
  final double hoverOffsetY;

  Particle3DPainter({
    required this.particles,
    required this.shootingStars,
    required this.elapsedTime,
    required this.spread,
    required this.baseSize,
    required this.sizeRandomness,
    required this.cameraDistance,
    required this.disableRotation,
    required this.alphaParticles,
    required this.pixelRatio,
    required this.hoverOffsetX,
    required this.hoverOffsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;
    
    final centerX = size.width / 2.0;
    final centerY = size.height / 2.0;

    // Camera rotation values
    final double rotX = disableRotation ? 0.0 : sin(elapsedTime * 0.01) * 0.06;
    final double rotY = disableRotation ? 0.0 : cos(elapsedTime * 0.03) * 0.08;
    final double rotZ = disableRotation ? 0.0 : elapsedTime * 0.05;

    final cosX = cos(rotX), sinX = sin(rotX);
    final cosY = cos(rotY), sinY = sin(rotY);
    final cosZ = cos(rotZ), sinZ = sin(rotZ);

    final paint = Paint();

    // 1. Draw particles (stars)
    for (var p in particles) {
      // Spreading formula
      double px = p.x * spread;
      double py = p.y * spread;
      double pz = p.z * spread * 10.0;

      // Wave offset animation
      px += sin(elapsedTime * p.rz + 6.28 * p.rw) * (0.1 + (1.2 - 0.1) * p.rx);
      py += sin(elapsedTime * p.ry + 6.28 * p.rx) * (0.1 + (1.2 - 0.1) * p.rw);
      pz += sin(elapsedTime * p.rw + 6.28 * p.ry) * (0.1 + (1.2 - 0.1) * p.rz);

      // Hover interaction offset
      px += hoverOffsetX;
      py += hoverOffsetY;

      // Rotation transformations
      // Y-axis rotation
      double x1 = px * cosY - pz * sinY;
      double z1 = px * sinY + pz * cosY;
      // X-axis rotation
      double y2 = py * cosX - z1 * sinX;
      double z2 = py * sinX + z1 * cosX;
      // Z-axis rotation
      double x3 = x1 * cosZ - y2 * sinZ;
      double y3 = x1 * sinZ + y2 * cosZ;

      // Perspective Camera projection mapping
      double cameraDepth = cameraDistance + z2;
      if (cameraDepth <= 0.1) continue;

      double scale = cameraDistance / cameraDepth;
      
      double screenX = centerX + x3 * scale * (size.width / 40.0);
      double screenY = centerY + y3 * scale * (size.height / 40.0);

      if (screenX < -50 || screenX > size.width + 50 || screenY < -50 || screenY > size.height + 50) {
        continue;
      }

      // Compute point sizing
      double sizeFactor;
      if (sizeRandomness == 0.0) {
        sizeFactor = baseSize;
      } else {
        sizeFactor = baseSize * (1.0 + sizeRandomness * (p.rx - 0.5));
      }
      
      // Calculate star radius
      double radius = (sizeFactor * scale) / (cameraDepth * pixelRatio * 2.0);
      if (radius <= 0.1) continue;

      // Apply twinkling effect
      double alphaMultiplier = 1.0;
      if (p.starType == StarType.twinkle) {
        alphaMultiplier = 0.2 + 0.8 * ((sin(elapsedTime * 4.0 + p.rx * 50.0) + 1.0) / 2.0);
      } else if (p.starType == StarType.flare) {
        alphaMultiplier = 0.5 + 0.5 * ((cos(elapsedTime * 2.5 + p.ry * 30.0) + 1.0) / 2.0);
      }

      int alphaVal = ((p.rx * 180).round() + 75);
      alphaVal = (alphaVal * alphaMultiplier).round().clamp(0, 255);

      if (alphaParticles) {
        // Soft Glow
        paint.color = p.color.withAlpha(alphaVal);
        paint.shader = RadialGradient(
          colors: [
            p.color.withAlpha(alphaVal),
            p.color.withAlpha(0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(screenX, screenY), radius: radius * 2.0));
        
        canvas.drawCircle(Offset(screenX, screenY), radius * 2.0, paint);
        paint.shader = null;
      } else {
        paint.color = p.color.withAlpha(alphaVal);
        canvas.drawCircle(Offset(screenX, screenY), radius, paint);
      }

      // Draw cross flare glow lines for brighter flare stars
      if (p.starType == StarType.flare && alphaVal > 100) {
        final flarePaint = Paint()
          ..color = p.color.withAlpha((alphaVal * 0.35).round())
          ..strokeWidth = 0.8;
        canvas.drawLine(
          Offset(screenX - radius * 4.5, screenY),
          Offset(screenX + radius * 4.5, screenY),
          flarePaint,
        );
        canvas.drawLine(
          Offset(screenX, screenY - radius * 4.5),
          Offset(screenX, screenY + radius * 4.5),
          flarePaint,
        );
      }
    }

    // 2. Draw shooting stars / comets
    for (var s in shootingStars) {
      final dx = s.endX - s.startX;
      final dy = s.endY - s.startY;
      final headX = s.startX + dx * s.progress;
      final headY = s.startY + dy * s.progress;

      // Calculate trail length
      const trailLength = 70.0;
      final dist = sqrt(dx * dx + dy * dy);
      final trailProgress = max(0.0, s.progress - (trailLength / dist));
      final trailX = s.startX + dx * trailProgress;
      final trailY = s.startY + dy * trailProgress;

      // Draw fading trail line
      final trailPaint = Paint()
        ..strokeWidth = s.size
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromPoints(Offset(trailX, trailY), Offset(headX, headY)));

      canvas.drawLine(Offset(trailX, trailY), Offset(headX, headY), trailPaint);

      // Draw bright head
      final headPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
      canvas.drawCircle(Offset(headX, headY), s.size, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
