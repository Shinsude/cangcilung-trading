part of 'package:cangcilung_trading/screens/home_screen.dart';

class _IndicatorBlock extends StatelessWidget {
  const _IndicatorBlock({required this.ind, this.vp, this.decimals});

  final Indicators ind;
  final VolumeProfile? vp;
  final int? decimals;

  @override
  Widget build(BuildContext context) {
    final rsiColor = ind.rsi.value < 30
        ? AppColors.green
        : ind.rsi.value > 70
            ? AppColors.red
            : AppColors.amber;
    final bbPos = ind.bollinger.percentB ?? 0.5;
    final bbPosColor = bbPos < 0.3 ? AppColors.green : bbPos > 0.7 ? AppColors.red : AppColors.amber;
    final macdColor = ind.macd.histogram >= 0 ? AppColors.green : AppColors.red;
    final emaColor = ind.ema.trend == 'bullish' ? AppColors.green : AppColors.red;
    final vpPosColor = vp != null && vp!.pricePos == 'ABOVE'
        ? Colors.deepOrange
        : vp != null && vp!.pricePos == 'BELOW'
            ? Colors.cyan
            : AppColors.amber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INDIKATOR TEKNIKAL', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            children: [
              _IndicatorTile(icon: Icons.speed_rounded, label: 'RSI (14)', value: ind.rsi.value.toStringAsFixed(1), color: rsiColor),
              _IndicatorTile(icon: Icons.show_chart_rounded, label: 'MACD', value: ind.macd.histogram.toStringAsFixed(4), color: macdColor),
              _IndicatorTile(icon: Icons.trending_up_rounded, label: 'EMA Trend', value: ind.ema.trend, color: emaColor),
              _IndicatorTile(icon: Icons.bolt_rounded, label: 'Bollinger %B', value: bbPos.toStringAsFixed(2), color: bbPosColor),
              _IndicatorTile(icon: Icons.waves_rounded, label: 'Volatilitas', value: '${(ind.volatility20 * 100).toStringAsFixed(2)}%', color: AppColors.purple),
              _IndicatorTile(icon: Icons.straighten_rounded, label: 'ATR (14)', value: ind.atr != null ? ind.atr!.toStringAsFixed(ind.atr! < 1 ? 5 : 2) : '\u2014', color: AppColors.amber),
              _IndicatorTile(icon: Icons.speed_rounded, label: 'SMA 20', value: ind.sma20.toStringAsFixed(2), color: AppColors.blue),
              if (vp != null && vp!.available) ...[
                _IndicatorTile(icon: Icons.bar_chart_rounded, label: 'POC', value: vp!.poc!.toStringAsFixed(decimals ?? 2), color: AppColors.purple),
                _IndicatorTile(icon: Icons.gradient_rounded, label: 'VA WIDTH', value: '${(vp!.vaWidthPct ?? 0).toStringAsFixed(1)}%', color: vpPosColor),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  const _IndicatorTile({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18, fontFeatures: const [FontFeature.tabularFigures()]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}