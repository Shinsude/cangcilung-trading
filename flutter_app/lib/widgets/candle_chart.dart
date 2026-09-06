import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

class CandleChart extends StatelessWidget {
  const CandleChart({super.key, required this.candles, required this.decimals});

  final List<Candle> candles;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Belum ada data chart')),
      );
    }
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: CustomPaint(painter: _CandlePainter(candles, decimals)),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter(this.candles, this.decimals);

  final List<Candle> candles;
  final int decimals;

  static const double _topPad = 20;
  static const double _bottomPad = 28;

  @override
  void paint(Canvas canvas, Size size) {
    double minPrice = candles.last.l;
    double maxPrice = candles.last.h;
    for (final c in candles) {
      if (c.h > maxPrice) maxPrice = c.h;
      if (c.l < minPrice) minPrice = c.l;
    }
    final span = maxPrice - minPrice;
    if (span == 0) return;
    final chartH = size.height - _topPad - _bottomPad;

    double xFor(int i) => (size.width / candles.length) * i + size.width / candles.length / 2;
    double yFor(double price) => _topPad + (chartH * (maxPrice - price) / span);

    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = _topPad + chartH * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      final priceLabel = maxPrice - span * i / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: _fmt(priceLabel),
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 8, fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 4, y - tp.height / 2));
    }

    final candleWidth = size.width / candles.length * 0.6;
    final greenPaint = Paint()..color = AppColors.green;
    final redPaint = Paint()..color = AppColors.red;
    final wickPaint = Paint()
      ..color = AppColors.textTertiary
      ..strokeWidth = 0.8;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isUp = c.c >= c.o;
      final x = xFor(i);
      canvas.drawLine(Offset(x, yFor(c.h)), Offset(x, yFor(c.l)), wickPaint);
      final top = yFor(isUp ? c.h : c.l);
      final bottom = yFor(isUp ? c.l : c.h);
      final h = (bottom - top).clamp(1.0, double.infinity);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - candleWidth / 2, top, candleWidth, h),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, isUp ? greenPaint : redPaint);
    }

    final last = candles.last;
    final isUp = last.c >= last.o;
    final lastColor = isUp ? AppColors.green : AppColors.red;
    final lastY = yFor(last.c);

    final guidePaint = Paint()
      ..color = lastColor.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawDashedLine(Offset(0, lastY), Offset(size.width, lastY), guidePaint, dashLen: 4, gapLen: 3);

    final tagText = TextPainter(
      text: TextSpan(
        text: ' ${_fmt(last.c)} ',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, backgroundColor: lastColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final tagLeft = size.width - tagText.width - 6;
    final tagTop = lastY - tagText.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tagLeft - 4, tagTop, tagText.width + 8, tagText.height),
        const Radius.circular(4),
      ),
      Paint()..color = lastColor,
    );
    tagText.paint(canvas, Offset(tagLeft, tagTop));

    final minLabel = TextPainter(
      text: TextSpan(text: _fmt(minPrice), style: const TextStyle(color: AppColors.textTertiary, fontSize: 8, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    minLabel.paint(canvas, Offset(4, size.height - _bottomPad + 8));

    final maxLabel = TextPainter(
      text: TextSpan(text: _fmt(maxPrice), style: const TextStyle(color: AppColors.textTertiary, fontSize: 8, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    maxLabel.paint(canvas, const Offset(4, 4));
  }

  String _fmt(double v) => v.toStringAsFixed(decimals);

  @override
  bool shouldRepaint(covariant _CandlePainter old) => old.candles != candles;
}

extension on Canvas {
  void drawDashedLine(Offset start, Offset end, Paint paint, {double dashLen = 5, double gapLen = 3}) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len;
    final uy = dy / len;
    double d = 0;
    while (d < len) {
      final s = Offset(start.dx + ux * d, start.dy + uy * d);
      final e = Offset(start.dx + ux * (d + dashLen).clamp(0, len), start.dy + uy * (d + dashLen).clamp(0, len));
      drawLine(s, e, paint);
      d += dashLen + gapLen;
    }
  }
}
