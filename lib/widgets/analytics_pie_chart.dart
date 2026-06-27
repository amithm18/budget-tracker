import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnalyticsPieChart extends StatefulWidget {
  final Map<String, double> data;
  final Map<String, Color> colors;
  final Map<String, String> emojis;
  final String currencySymbol;

  const AnalyticsPieChart({
    super.key,
    required this.data,
    required this.colors,
    required this.emojis,
    this.currencySymbol = '₹',
  });

  @override
  State<AnalyticsPieChart> createState() => _AnalyticsPieChartState();
}

class _AnalyticsPieChartState extends State<AnalyticsPieChart> {
  int _selectedIndex = -1; // -1 means no segment is currently highlighted

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();
    final total = entries.fold<double>(0.0, (sum, item) => sum + item.value);

    // If there is no spending data, show a placeholder settled state
    if (total == 0) {
      return Center(
        child: Container(
          height: 180,
          width: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.bgSurface,
            border: Border.all(color: AppTheme.border, width: 2),
          ),
          alignment: Alignment.center,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("🤝", style: TextStyle(fontSize: 32)),
              SizedBox(height: 8),
              Text(
                "Settle Up",
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              Text(
                "No expenses log",
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = min(constraints.maxWidth, 240);
        final double centerX = size / 2;
        final double centerY = size / 2;
        final double outerRadius = size / 2;
        final double strokeWidth = 32.0;
        final double innerRadius = outerRadius - strokeWidth;

        return Center(
          child: GestureDetector(
            onTapDown: (details) {
              final double dx = details.localPosition.dx - centerX;
              final double dy = details.localPosition.dy - centerY;
              final double distance = sqrt(dx * dx + dy * dy);

              // Validate if the tap fell inside the active donut ring area
              if (distance >= innerRadius - 8 && distance <= outerRadius + 8) {
                // Determine touch angle in radians relative to the top vertical (-pi/2)
                double angle = atan2(dy, dx);
                double touchAngle = angle + pi / 2;
                if (touchAngle < 0) {
                  touchAngle += 2 * pi;
                }
                
                // Track which slice wraps around this angle range
                double currentStartAngle = 0.0;
                int tappedIndex = -1;

                for (int i = 0; i < entries.length; i++) {
                  final double sweepAngle = (entries[i].value / total) * 2 * pi;
                  final double endAngle = currentStartAngle + sweepAngle;
                  
                  if (touchAngle >= currentStartAngle && touchAngle <= endAngle) {
                    tappedIndex = i;
                    break;
                  }
                  currentStartAngle = endAngle;
                }

                setState(() {
                  // If tapped the already selected segment, deselect it
                  _selectedIndex = (_selectedIndex == tappedIndex) ? -1 : tappedIndex;
                });
              } else {
                // Reset selection if tapped outside the ring
                setState(() {
                  _selectedIndex = -1;
                });
              }
            },
            child: SizedBox(
              height: size,
              width: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vector CustomPaint Donut Chart drawing
                  CustomPaint(
                    size: Size(size, size),
                    painter: DonutChartPainter(
                      data: entries,
                      colors: widget.colors,
                      total: total,
                      selectedIndex: _selectedIndex,
                      strokeWidth: strokeWidth,
                    ),
                  ),
                  
                  // Central Summary Details Card (sits inside the empty donut space)
                  Container(
                    height: size - (strokeWidth * 2) - 12,
                    width: size - (strokeWidth * 2) - 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.bgDark,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _selectedIndex == -1
                          ? [
                              const Text(
                                "TOTAL SPEND",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${widget.currencySymbol}${total.toStringAsFixed(0)}",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ]
                          : [
                              Text(
                                widget.emojis[entries[_selectedIndex].key] ?? "💰",
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entries[_selectedIndex].key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${widget.currencySymbol}${entries[_selectedIndex].value.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: widget.colors[entries[_selectedIndex].key] ?? AppTheme.primaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final Map<String, Color> colors;
  final double total;
  final int selectedIndex;
  final double strokeWidth;

  DonutChartPainter({
    required this.data,
    required this.colors,
    required this.total,
    required this.selectedIndex,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    double startAngle = -pi / 2; // Start from top vertical

    for (int i = 0; i < data.length; i++) {
      final double sweepAngle = (data[i].value / total) * 2 * pi;
      final color = colors[data[i].key] ?? Colors.grey;

      // Draw highlighted/active segment larger
      final isSelected = selectedIndex == i;
      
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 6.0 : strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = isSelected ? color : color.withOpacity(0.85);

      // Create a visual gap between segments by reducing the sweep angle slightly
      // Only apply segment spacing if there are multiple categories
      final gapAdjustment = data.length > 1 ? 0.08 : 0.0;

      canvas.drawArc(
        rect,
        startAngle + (gapAdjustment / 2),
        sweepAngle - gapAdjustment,
        false,
        paint,
      );

      // Increment angle for the next segment
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.total != total ||
      oldDelegate.data != data;
}
