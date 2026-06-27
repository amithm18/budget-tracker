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

  Particle3D({
    required this.x,
    required this.y,
    required this.z,
    required this.rx,
    required this.ry,
    required this.rz,
    required this.rw,
    required this.color,
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
    this.particleCount = 100, // Reduced from 200 for butter-smooth mobile execution
    this.particleSpread = 15.0,
    this.speed = 0.05,
    this.particleColors = const ['#5F5DEC', '#0EA5E9', '#FFFFFF'], // Indigo, Sky Blue, and White stardust
    this.moveParticlesOnHover = true,
    this.particleHoverFactor = 1.0,
    this.alphaParticles = true,
    this.particleBaseSize = 40.0,
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
      
      _particles.add(Particle3D(
        x: x * r,
        y: y * r,
        z: z * r,
        rx: _random.nextDouble(),
        ry: _random.nextDouble(),
        rz: _random.nextDouble(),
        rw: _random.nextDouble(),
        color: colors[_random.nextInt(colors.length)],
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
          // Normalize mouse coordinates to [-1, 1] as in WebGL
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
          _updatePhysics();
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: Particle3DPainter(
                    particles: _particles,
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

  void _updatePhysics() {
    // Increment time delta based on speed multiplier
    _elapsedTime += widget.speed * 0.16; // Approx tick rate
    
    // Lerp hover mouse tracking coordinate to create smooth movement delays
    _smoothMouseX += (_targetMouse.dx - _smoothMouseX) * 0.05;
    _smoothMouseY += (_targetMouse.dy - _smoothMouseY) * 0.05;
  }
}

class Particle3DPainter extends CustomPainter {
  final List<Particle3D> particles;
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

    // Standard camera rotation values from WebGL update loop
    final double rotX = disableRotation ? 0.0 : sin(elapsedTime * 0.02) * 0.1;
    final double rotY = disableRotation ? 0.0 : cos(elapsedTime * 0.05) * 0.15;
    final double rotZ = disableRotation ? 0.0 : elapsedTime * 0.1;

    final cosX = cos(rotX), sinX = sin(rotX);
    final cosY = cos(rotY), sinY = sin(rotY);
    final cosZ = cos(rotZ), sinZ = sin(rotZ);

    final paint = Paint();

    for (var p in particles) {
      // 1. Initial WebGL spreading formula
      double px = p.x * spread;
      double py = p.y * spread;
      double pz = p.z * spread * 10.0;

      // 2. Dynamic sinusoidal wave offset animations matching React shader
      px += sin(elapsedTime * p.rz + 6.28 * p.rw) * (0.1 + (1.5 - 0.1) * p.rx);
      py += sin(elapsedTime * p.ry + 6.28 * p.rx) * (0.1 + (1.5 - 0.1) * p.rw);
      pz += sin(elapsedTime * p.rw + 6.28 * p.ry) * (0.1 + (1.5 - 0.1) * p.rz);

      // Apply hover interaction offset
      px += hoverOffsetX;
      py += hoverOffsetY;

      // 3. Apply 3D rotation transformations
      // Y-axis rotation
      double x1 = px * cosY - pz * sinY;
      double z1 = px * sinY + pz * cosY;
      // X-axis rotation
      double y2 = py * cosX - z1 * sinX;
      double z2 = py * sinX + z1 * cosX;
      // Z-axis rotation
      double x3 = x1 * cosZ - y2 * sinZ;
      double y3 = x1 * sinZ + y2 * cosZ;

      // 4. Perspective Camera projection mapping
      // Camera sits at (0, 0, cameraDistance). Offset particle coordinate along Z.
      double cameraDepth = cameraDistance + z2;
      if (cameraDepth <= 0.1) continue; // Skip if behind camera

      // Projection multiplier based on camera field of depth
      double scale = cameraDistance / cameraDepth;
      
      // Map coordinates to center-oriented viewport
      double screenX = centerX + x3 * scale * (size.width / 40.0);
      double screenY = centerY + y3 * scale * (size.height / 40.0);

      // Skip drawing if coordinates fall completely off-screen
      if (screenX < -50 || screenX > size.width + 50 || screenY < -50 || screenY > size.height + 50) {
        continue;
      }

      // 5. Compute point sizing relative to perspective depth
      double sizeFactor;
      if (sizeRandomness == 0.0) {
        sizeFactor = baseSize;
      } else {
        sizeFactor = baseSize * (1.0 + sizeRandomness * (p.rx - 0.5));
      }
      
      // Final radius scale
      double radius = (sizeFactor * scale) / (cameraDepth * pixelRatio * 2.0);
      if (radius <= 0.1) continue;

      // 6. Color drawing and alpha variations
      if (alphaParticles) {
        // Render soft glow gradient for organic alpha effect
        paint.color = p.color.withAlpha((p.rx * 200).round() + 55);
        paint.shader = RadialGradient(
          colors: [
            p.color.withAlpha((p.rx * 220).round() + 35),
            p.color.withAlpha(0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(screenX, screenY), radius: radius * 1.5));
        
        canvas.drawCircle(Offset(screenX, screenY), radius * 1.5, paint);
        paint.shader = null; // Reset shader
      } else {
        // Render solid color dot
        paint.color = p.color;
        canvas.drawCircle(Offset(screenX, screenY), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
