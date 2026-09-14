part of 'home_screen.dart';

class _IndicatorsPage extends StatelessWidget {
  const _IndicatorsPage({required this.ind, required this.price, this.weights = const {}});

  final Indicators ind;
  final double price;
  final Map<String, double> weights;

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
            _IndicatorTile(icon: Icons.speed_rounded, label: 'RSI (14)', value: ind.rsi.value.toStringAsFixed(1), sub: ind.rsi.region, color: rsiColor),
            _IndicatorTile(icon: Icons.show_chart_rounded, label: 'MACD', value: ind.macd.histogram.toStringAsFixed(4), sub: ind.macd.cross ?? 'neutral', color: macdColor),
            _IndicatorTile(icon: Icons.trending_up_rounded, label: 'EMA Trend', value: ind.ema.trend, sub: '9/21/50', color: emaColor),
            _IndicatorTile(icon: Icons.bolt_rounded, label: 'Bollinger %B', value: bbPos.toStringAsFixed(2), sub: 'Upper ${ind.bollinger.upper.toStringAsFixed(2)}', color: bbPosColor),
            _IndicatorTile(icon: Icons.waves_rounded, label: 'Volatilitas', value: '${(ind.volatility20 * 100).toStringAsFixed(2)}%', sub: 'SMA20 ${ind.sma20.toStringAsFixed(2)}', color: AppColors.purple),
            _IndicatorTile(icon: Icons.straighten_rounded, label: 'ATR (14)', value: ind.atr != null ? ind.atr!.toStringAsFixed(ind.atr! < 1 ? 5 : 2) : '—', sub: 'Dasar SL/TP', color: AppColors.amber),
            _IndicatorTile(icon: Icons.speed_rounded, label: 'SMA 20', value: ind.sma20.toStringAsFixed(2), sub: 'Harga: ${price.toStringAsFixed(2)}', color: AppColors.blue),
          ],
        ),
        const SizedBox(height: 20),
        const Text('BOBOT MODEL (AUTO-TUNE)', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        const Text(
          'Bobot hasil walk-forward backtest per simbol: indikator yang paling akurat diperkuat (hijau), yang paling lemah diredam (biru).',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 10, height: 1.4),
        ),
        const SizedBox(height: 10),
        if (weights.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: weights.entries.map((e) => _WeightChip(label: e.key, weight: e.value)).toList(),
          )
        else
          const Text('Belum tersedia', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
      ],
    );
  }
}

class _WeightChip extends StatelessWidget {
  const _WeightChip({required this.label, required this.weight});
  final String label;
  final double weight;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (weight > 1.05) {
      color = AppColors.green;
    } else if (weight < 0.95) {
      color = AppColors.blue;
    } else {
      color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(weight.toStringAsFixed(1), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _IndicatorTile extends StatelessWidget {
  const _IndicatorTile({required this.icon, required this.label, required this.value, required this.sub, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
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
            overflow: TextOverflow.ellipsis,
          ),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
