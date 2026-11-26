import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';

class UsageChart extends StatefulWidget {
  final List<ChartPoint> points;
  final double height;
  final String language;

  const UsageChart({
    super.key,
    required this.points,
    this.height = 240,
    this.language = 'en',
  });

  @override
  State<UsageChart> createState() => _UsageChartState();
}

class _UsageChartState extends State<UsageChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text(
            widget.language == 'ar' ? 'لا توجد بيانات شبكة مسجلة' : 'No network activity recorded',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Legend & Tooltip Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildLegendItem(
                  color: AppColors.downloadColor,
                  label: widget.language == 'ar' ? 'التحميل' : 'Download',
                ),
                const SizedBox(width: 16),
                _buildLegendItem(
                  color: AppColors.uploadColor,
                  label: widget.language == 'ar' ? 'الرفع' : 'Upload',
                ),
              ],
            ),
            if (_hoveredIndex != null && _hoveredIndex! < widget.points.length)
              _buildHoverInfo(widget.points[_hoveredIndex!]),
          ],
        ),
        const SizedBox(height: 12),
        // Chart Canvas
        SizedBox(
          height: widget.height,
          child: MouseRegion(
            onHover: (event) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final localX = event.localPosition.dx;
                final width = box.size.width;
                if (widget.points.length > 1) {
                  final step = width / (widget.points.length - 1);
                  final idx = (localX / step).round().clamp(0, widget.points.length - 1);
                  setState(() => _hoveredIndex = idx);
                }
              }
            },
            onExit: (_) => setState(() => _hoveredIndex = null),
            child: CustomPaint(
              size: Size.infinite,
              painter: _GlassWireChartPainter(
                points: widget.points,
                hoveredIndex: _hoveredIndex,
                isDark: isDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildHoverInfo(ChartPoint pt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkCardHover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${pt.label}: ',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            '↓ ${formatBytes(pt.rx, lang: widget.language)}',
            style: const TextStyle(fontSize: 11, color: AppColors.downloadColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            '↑ ${formatBytes(pt.tx, lang: widget.language)}',
            style: const TextStyle(fontSize: 11, color: AppColors.uploadColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _GlassWireChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final int? hoveredIndex;
  final bool isDark;

  _GlassWireChartPainter({
    required this.points,
    this.hoveredIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paddingBottom = 24.0;
    final chartHeight = size.height - paddingBottom;
    final chartWidth = size.width;

    num maxVal = 1024 * 1024; // min 1MB ceiling
    for (var p in points) {
      if (p.rx > maxVal) maxVal = p.rx;
      if (p.tx > maxVal) maxVal = p.tx;
    }
    // Round ceiling to nice number
    maxVal = maxVal * 1.15;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines
    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = chartHeight * (i / gridLines);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    final n = points.length;
    final dx = n > 1 ? chartWidth / (n - 1) : chartWidth;

    // Path definitions
    final rxPath = Path();
    final txPath = Path();
    final rxFillPath = Path();
    final txFillPath = Path();

    List<Offset> rxOffsets = [];
    List<Offset> txOffsets = [];

    for (int i = 0; i < n; i++) {
      final x = i * dx;
      final yRx = chartHeight - (points[i].rx / maxVal) * chartHeight;
      final yTx = chartHeight - (points[i].tx / maxVal) * chartHeight;
      rxOffsets.add(Offset(x, yRx));
      txOffsets.add(Offset(x, yTx));
    }

    // Build smooth curves
    _buildSmoothPath(rxPath, rxOffsets);
    _buildSmoothPath(txPath, txOffsets);

    // Build filled areas
    rxFillPath.addPath(rxPath, Offset.zero);
    rxFillPath.lineTo(rxOffsets.last.dx, chartHeight);
    rxFillPath.lineTo(rxOffsets.first.dx, chartHeight);
    rxFillPath.close();

    txFillPath.addPath(txPath, Offset.zero);
    txFillPath.lineTo(txOffsets.last.dx, chartHeight);
    txFillPath.lineTo(txOffsets.first.dx, chartHeight);
    txFillPath.close();

    // Fill download area (Cyan gradient)
    final rxGradient = LinearGradient(
      colors: [AppColors.downloadColor.withOpacity(0.28), AppColors.downloadColor.withOpacity(0.01)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, chartWidth, chartHeight));
    canvas.drawPath(rxFillPath, Paint()..shader = rxGradient);

    // Fill upload area (Teal gradient)
    final txGradient = LinearGradient(
      colors: [AppColors.uploadColor.withOpacity(0.22), AppColors.uploadColor.withOpacity(0.01)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(0, 0, chartWidth, chartHeight));
    canvas.drawPath(txFillPath, Paint()..shader = txGradient);

    // Draw lines
    final rxStroke = Paint()
      ..color = AppColors.downloadColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(rxPath, rxStroke);

    final txStroke = Paint()
      ..color = AppColors.uploadColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(txPath, txStroke);

    // Draw X-axis labels
    final textStyle = TextStyle(
      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final labelStep = math.max(1, (n / 8).ceil());
    for (int i = 0; i < n; i += labelStep) {
      final span = TextSpan(text: points[i].label, style: textStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      final x = (i * dx) - (tp.width / 2);
      tp.paint(canvas, Offset(x.clamp(0, chartWidth - tp.width), chartHeight + 6));
    }

    // Draw hover indicator
    if (hoveredIndex != null && hoveredIndex! < n) {
      final hx = hoveredIndex! * dx;
      final hoverLinePaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(hx, 0), Offset(hx, chartHeight), hoverLinePaint);

      // Points on lines
      canvas.drawCircle(rxOffsets[hoveredIndex!], 5, Paint()..color = AppColors.downloadColor);
      canvas.drawCircle(rxOffsets[hoveredIndex!], 2.5, Paint()..color = Colors.white);

      canvas.drawCircle(txOffsets[hoveredIndex!], 4, Paint()..color = AppColors.uploadColor);
      canvas.drawCircle(txOffsets[hoveredIndex!], 2, Paint()..color = Colors.white);
    }
  }

  void _buildSmoothPath(Path path, List<Offset> points) {
    if (points.isEmpty) return;
    path.moveTo(points[0].dx, points[0].dy);
    if (points.length == 1) return;

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassWireChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.hoveredIndex != hoveredIndex;
  }
}
