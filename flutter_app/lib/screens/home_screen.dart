import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/candle_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final List<String> _symbols = ['XAUUSD', 'NASDAQ', 'AUDUSD'];
  String _selected = 'XAUUSD';
  TradingData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchSignal(_selected);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectSymbol(String s) {
    if (s == _selected) return;
    setState(() => _selected = s);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cangcilung Trading AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SymbolSelector(symbols: _symbols, selected: _selected, onSelect: _selectSymbol),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : _Dashboard(data: _data!, onRefresh: _load),
            ),
          ],
        ),
      ),
    );
  }
}

class _SymbolSelector extends StatelessWidget {
  const _SymbolSelector({required this.symbols, required this.selected, required this.onSelect});

  final List<String> symbols;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          for (final s in symbols) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: s == selected ? AppColors.blue.withValues(alpha: 0.18) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: s == selected ? AppColors.blue : AppColors.border,
                      width: s == selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        s,
                        style: TextStyle(
                          color: s == selected ? AppColors.blue : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (s != symbols.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('Gagal mengambil data', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.data, required this.onRefresh});

  final TradingData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _PriceCard(data: data),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _PredictionCard(prediction: data.prediction, price: data.currentPrice, decimals: data.decimals)),
              const SizedBox(width: 12),
              Expanded(child: _SignalCard(signal: data.signal)),
            ],
          ),
          const SizedBox(height: 12),
          _ChartCard(data: data),
          const SizedBox(height: 12),
          _IndicatorsCard(ind: data.indicators, price: data.currentPrice),
          const SizedBox(height: 12),
          _SentimentCard(sentiment: data.sentiment),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.data});

  final TradingData data;

  @override
  Widget build(BuildContext context) {
    final up = data.changePct >= 0;
    final changeColor = up ? AppColors.green : AppColors.red;
    final priceStr = data.currentPrice.toStringAsFixed(data.decimals);
    final changeStr = '${up ? '+' : ''}${data.changePct.toStringAsFixed(2)}%';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(data.category, style: const TextStyle(color: AppColors.blue, fontSize: 11)),
                ),
                const Spacer(),
                Text(
                  data.symbol,
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              priceStr,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: up ? AppColors.green : AppColors.red,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(changeStr, style: TextStyle(color: changeColor, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text(data.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction, required this.price, required this.decimals});

  final Prediction prediction;
  final double price;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final dirColor = prediction.direction.toSignalColor();
    final arrow = prediction.direction == 'UP' ? '▲' : prediction.direction == 'DOWN' ? '▼' : '◆';
    final pct = price == 0 ? 0.0 : (prediction.nextPrice - price) / price * 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Prediksi', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Text(
              '$arrow ${prediction.direction}',
              style: TextStyle(color: dirColor, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              prediction.nextPrice.toStringAsFixed(decimals),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}% · ${prediction.horizon}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: prediction.confidence,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              backgroundColor: AppColors.surfaceAlt,
              color: dirColor,
            ),
            const SizedBox(height: 4),
            Text(
              'Confidence ${(prediction.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal});

  final Signal signal;

  @override
  Widget build(BuildContext context) {
    final color = signal.action.toSignalColor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sinyal', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                signal.action,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              signal.strength,
              style: TextStyle(color: signal.strength.toSignalColor(), fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: signal.confidence,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              backgroundColor: AppColors.surfaceAlt,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              'Confidence ${(signal.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
          mainAxisSize: MainAxisSize.min,
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.data});

  final TradingData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Chart', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${data.candles.length} candle terakhir', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            CandleChart(candles: data.candles, decimals: data.decimals),
          ],
        ),
      ),
    );
  }
}

class _IndicatorsCard extends StatelessWidget {
  const _IndicatorsCard({required this.ind, required this.price});

  final Indicators ind;
  final double price;

  @override
  Widget build(BuildContext context) {
    final rsiColor = ind.rsi.value < 30
        ? AppColors.green
        : ind.rsi.value > 70
            ? AppColors.red
            : AppColors.amber;
    final bbPos = ind.bollinger.percentB ?? 0.5;
    final bbPosColor = bbPos < 0.3 ? AppColors.green : bbPos > 0.7 ? AppColors.red : AppColors.amber;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Technical Indicators', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _IndicatorTile(
              icon: Icons.speed,
              label: 'RSI (14)',
              value: ind.rsi.value.toStringAsFixed(1),
              sub: ind.rsi.region,
              color: rsiColor,
            ),
            const Divider(height: 1),
            _IndicatorTile(
              icon: Icons.show_chart,
              label: 'MACD',
              value: ind.macd.histogram.toStringAsFixed(4),
              sub: ind.macd.cross ?? 'neutral',
              color: ind.macd.histogram >= 0 ? AppColors.green : AppColors.red,
            ),
            const Divider(height: 1),
            _IndicatorTile(
              icon: Icons.trending_up,
              label: 'EMA (9/21/50)',
              value: '${_s(ind.ema.ema9)} / ${_s(ind.ema.ema21)}',
              sub: 'Trend ${ind.ema.trend}',
              color: ind.ema.trend == 'bullish' ? AppColors.green : AppColors.red,
            ),
            const Divider(height: 1),
            _IndicatorTile(
              icon: Icons.bolt,
              label: 'Bollinger (%B)',
              value: bbPos.toStringAsFixed(2),
              sub: 'Upper ${_s(ind.bollinger.upper)}',
              color: bbPosColor,
            ),
            const Divider(height: 1),
            _IndicatorTile(
              icon: Icons.waves,
              label: 'Volatilitas 20',
              value: '${(ind.volatility20 * 100).toStringAsFixed(2)}%',
              sub: 'SMA20 ${_s(ind.sma20)}',
              color: AppColors.textPrimary,
            ),
            const SizedBox(height: 8),
            Text(
              'Harga saat ini: ${_s(price)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _s(double v) => v.toStringAsFixed(2);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _SentimentCard extends StatelessWidget {
  const _SentimentCard({required this.sentiment});

  final Sentiment sentiment;

  @override
  Widget build(BuildContext context) {
    final color = sentiment.label.toSignalColor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sentiment Berita', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(sentiment.label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(
                  'Score ${sentiment.score.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (sentiment.score + 1) / 2,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sentiment.source == 'finnhub'
                  ? 'Dari berita terbaru (Finnhub)'
                  : 'Estimasi dari momentum harga (berita aktual membutuhkan API key gratis:Finnhub)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}