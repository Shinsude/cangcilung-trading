import 'dart:async';

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
  bool _live = false;

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
        _live = true;
      });
      Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _live = false);
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.green, Colors.tealAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.candlestick_chart, size: 16, color: Colors.black),
            ),
            const SizedBox(width: 8),
            const Text('Cangcilung', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
            const SizedBox(width: 4),
            const Text('TRADING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 1.2)),
          ],
        ),
        actions: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (_live ? AppColors.green : AppColors.amber).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (_live ? AppColors.green : AppColors.amber).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _live ? AppColors.green : AppColors.amber,
                    boxShadow: [_live ? const BoxShadow(color: AppColors.green, blurRadius: 6) : BoxShadow(color: AppColors.amber.withValues(alpha: 0.6), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _live ? 'LIVE' : '…',
                  style: TextStyle(color: _live ? AppColors.green : AppColors.amber, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _SymbolSelector(symbols: _symbols, selected: _selected, onSelect: _selectSymbol),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.green))
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            for (final s in symbols) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: s == selected ? AppColors.surfaceAlt : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: s == selected
                          ? [BoxShadow(color: AppColors.blue.withValues(alpha: 0.18), blurRadius: 10, spreadRadius: -2)]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          s,
                          style: TextStyle(
                            color: s == selected ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight: s == selected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s == selected ? AppColors.green : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceAlt,
              ),
              child: const Icon(Icons.cloud_off, size: 34, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('Terjadi Kesalahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.green, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
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
      color: AppColors.green,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _PriceCard(data: data),
          const SizedBox(height: 12),
          _SignalBanner(signal: data.signal, prediction: data.prediction, price: data.currentPrice, decimals: data.decimals),
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
    final accent = up ? AppColors.green : AppColors.red;
    final priceStr = data.currentPrice.toStringAsFixed(data.decimals);
    final changeStr = '${up ? '+' : ''}${data.changePct.toStringAsFixed(2)}%';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            (up ? AppColors.greenSoft : AppColors.redSoft).withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
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
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
                ),
                child: Text(data.category.toUpperCase(), style: const TextStyle(color: AppColors.blue, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              ),
              const Spacer(),
              Text(data.symbol, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            priceStr,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.5,
              shadows: [Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 18)],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: accent),
                    const SizedBox(width: 3),
                    Text(changeStr, style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalBanner extends StatelessWidget {
  const _SignalBanner({required this.signal, required this.prediction, required this.price, required this.decimals});

  final Signal signal;
  final Prediction prediction;
  final double price;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final sigColor = signal.action.toSignalColor();
    final dirColor = prediction.direction.toSignalColor();
    final arrow = prediction.direction == 'UP' ? '▲' : prediction.direction == 'DOWN' ? '▼' : '◆';
    final pct = price == 0 ? 0.0 : (prediction.nextPrice - price) / price * 100;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [sigColor.withValues(alpha: 0.18), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: sigColor.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: sigColor.withValues(alpha: 0.12), blurRadius: 22, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sinyal Trading', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(color: sigColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(signal.strength.toUpperCase(), style: TextStyle(color: sigColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal.action,
                      style: TextStyle(
                        color: sigColor,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        shadows: [Shadow(color: sigColor.withValues(alpha: 0.5), blurRadius: 16)],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(_score2icon(signal.confidence), size: 16, color: sigColor),
                        const SizedBox(width: 4),
                        Text(
                          '${(signal.confidence * 100).toStringAsFixed(0)}% keyakinan',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 56,
                color: AppColors.border,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$arrow ${prediction.direction}',
                      style: TextStyle(color: dirColor, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prediction.nextPrice.toStringAsFixed(decimals),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}% · ${prediction.horizon}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: signal.confidence),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
                color: sigColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _score2icon(double c) => c >= 0.75 ? Icons.local_fire_department : Icons.bolt;
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
                const Icon(Icons.candlestick_chart, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Price Chart', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(6)),
                  child: Text('${data.candles.length} harga terakhir', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
            const Row(
              children: [
                Icon(Icons.insights, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Technical Indicators', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
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
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14, fontFeatures: const [FontFeature.tabularFigures()])),
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
    final isNews = sentiment.headlines.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.newspaper, size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Market Sentiment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sentiment.label == 'BULLISH' ? Icons.trending_up : sentiment.label == 'BEARISH' ? Icons.trending_down : Icons.trending_flat, size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(sentiment.label, style: TextStyle(color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Score ${sentiment.score.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: (sentiment.score + 1) / 2,
                minHeight: 8,
                backgroundColor: AppColors.surfaceAlt,
                color: color,
              ),
            ),
            if (isNews) ...[
              const SizedBox(height: 12),
              const Text('Berita Terbaru', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final h in sentiment.headlines.take(3)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          h,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ] else
              const SizedBox(height: 8),
            Text(
              sentiment.source,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
