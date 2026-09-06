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
      height: 220,
      width: double.infinity,
      child: CustomPaint(painter: _CandlePainter(candles, decimals)),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter(this.candles, this.decimals);

  final List<Candle> candles;
  final int decimals;

  static const double _topPad = 16;
  static const double _bottomPad = 22;

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

    final gridColor = AppColors.border.withValues(alpha: 0.35);
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = _topPad + chartH * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final candleWidth = size.width / candles.length * 0.62;
    final greenPaint = Paint()..color = AppColors.green;
    final redPaint = Paint()..color = AppColors.red;
    final wickPaint = Paint()..color = AppColors.textSecondary..strokeWidth = 1;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isUp = c.c >= c.o;
      final x = xFor(i);
      canvas.drawLine(Offset(x, yFor(c.h)), Offset(x, yFor(c.l)), wickPaint);
      final top = yFor(isUp ? c.h : c.l);
      final bottom = yFor(isUp ? c.l : c.h);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x - candleWidth / 2, top, x + candleWidth / 2, bottom),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, isUp ? greenPaint : redPaint);
    }

    const textStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 9,
    );
    final tp = TextPainter(
      text: TextSpan(text: _fmt(maxPrice), style: textStyle),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, const Offset(4, 2));
    final bp = TextPainter(
      text: TextSpan(text: _fmt(minPrice), style: textStyle),
      textDirection: TextDirection.ltr,
    );
    bp.layout();
    bp.paint(canvas, Offset(4, size.height - _bottomPad + 6));

    final last = candles.last;
    final isUp = last.c >= last.o;
    final lastColor = isUp ? AppColors.green : AppColors.red;
    final lastY = yFor(last.c);
    final guidePaint = Paint()
      ..color = lastColor.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, lastY), Offset(size.width, lastY), guidePaint);

    final tagPaint = Paint()..color = lastColor;
    const tagWidth = 54.0;
    const tagH = 16.0;
    final tagLeft = size.width - tagWidth - 4;
    final tagTop = lastY - 8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tagLeft, tagTop, tagWidth, tagH),
        const Radius.circular(4),
      ),
      tagPaint,
    );
    final tagText = TextPainter(
      text: TextSpan(
        text: _fmt(last.c),
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tagText.layout();
    tagText.paint(canvas, Offset(tagLeft + (tagWidth - tagText.width) / 2, tagTop + 3));
  }

  String _fmt(double v) => v.toStringAsFixed(decimals);

  @override
  bool shouldRepaint(covariant _CandlePainter old) => old.candles != candles;
}