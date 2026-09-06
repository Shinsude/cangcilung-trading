import 'dart:async';
import 'dart:math';

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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final List<String> _symbols = ['XAUUSD', 'NASDAQ', 'AUDUSD'];
  String _selected = 'XAUUSD';
  TradingData? _data;
  String? _error;
  bool _loading = true;
  bool _live = false;
  int _tab = 0;

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
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
      Timer(const Duration(seconds: 4), () {
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
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(symbols: _symbols, selected: _selected, onSelect: _selectSymbol, live: _live),
            Expanded(
              child: _loading
                  ? const _LoadingView()
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : _buildBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: EdgeInsets.only(bottom: bottomPad),
        child: _BottomNav(
          tab: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: [
        _SignalPage(data: d, onRefresh: _load, pulse: _pulseCtrl),
        _ChartPage(data: d),
        _IndicatorsPage(ind: d.indicators, price: d.currentPrice),
        _SentimentPage(sentiment: d.sentiment),
      ][_tab],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.symbols, required this.selected, required this.onSelect, required this.live});

  final List<String> symbols;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.green, AppColors.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.candlestick_chart, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cangcilung', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
                  Text('TRADING AI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 9, color: AppColors.textSecondary, letterSpacing: 1.5)),
                ],
              ),
              const Spacer(),
              _LiveIndicator(live: live),
            ],
          ),
          const SizedBox(height: 12),
          _SymbolBar(symbols: symbols, selected: selected, onSelect: onSelect),
        ],
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.live});
  final bool live;

  @override
  Widget build(BuildContext context) {
    final c = live ? AppColors.green : AppColors.textTertiary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              boxShadow: live ? [BoxShadow(color: AppColors.green, blurRadius: 8, spreadRadius: 1)] : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            live ? 'LIVE' : 'OFFLINE',
            style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

class _SymbolBar extends StatelessWidget {
  const _SymbolBar({required this.symbols, required this.selected, required this.onSelect});

  final List<String> symbols;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in symbols) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: s != symbols.last ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: s == selected ? AppColors.blue.withValues(alpha: 0.15) : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: s == selected ? AppColors.blue.withValues(alpha: 0.4) : AppColors.border,
                  ),
                  boxShadow: s == selected ? [BoxShadow(color: AppColors.blue.withValues(alpha: 0.12), blurRadius: 12)] : null,
                ),
                child: Column(
                  children: [
                    Text(
                      s,
                      style: TextStyle(
                        color: s == selected ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: s == selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s == selected ? AppColors.blue : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.onChanged});

  final int tab;
  final ValueChanged<int> onChanged;

  static const _icons = [Icons.auto_graph, Icons.candlestick_chart, Icons.insights, Icons.newspaper];
  static const _labels = ['Signal', 'Chart', 'Indikator', 'Sentimen'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) {
        final active = i == tab;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _icons[i],
                    size: 22,
                    color: active ? AppColors.blue : AppColors.textTertiary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? AppColors.blue : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(color: AppColors.blue, strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text('Memuat data pasar...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceAlt,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('Gagal Memuat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalPage extends StatelessWidget {
  const _SignalPage({required this.data, required this.onRefresh, required this.pulse});

  final TradingData data;
  final Future<void> Function() onRefresh;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _PriceHero(data: data),
          const SizedBox(height: 14),
          _SignalHero(signal: data.signal, prediction: data.prediction, price: data.currentPrice, decimals: data.decimals, pulse: pulse),
          const SizedBox(height: 14),
          _QuickIndicators(ind: data.indicators),
        ],
      ),
    );
  }
}

class _PriceHero extends StatelessWidget {
  const _PriceHero({required this.data});
  final TradingData data;

  @override
  Widget build(BuildContext context) {
    final up = data.changePct >= 0;
    final accent = up ? AppColors.green : AppColors.red;
    final priceStr = data.currentPrice.toStringAsFixed(data.decimals);
    final changeStr = '${up ? '+' : ''}${data.changePct.toStringAsFixed(2)}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 10)),
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
                  color: AppColors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.blue.withValues(alpha: 0.25)),
                ),
                child: Text(data.category.toUpperCase(), style: const TextStyle(color: AppColors.blue, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Text(data.symbol, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.3)),
              const Spacer(),
              Text(data.name, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            priceStr,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: accent,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -1,
              height: 1,
              shadows: [Shadow(color: accent.withValues(alpha: 0.35), blurRadius: 20)],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 15, color: accent),
                const SizedBox(width: 4),
                Text(changeStr, style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalHero extends StatelessWidget {
  const _SignalHero({required this.signal, required this.prediction, required this.price, required this.decimals, required this.pulse});

  final Signal signal;
  final Prediction prediction;
  final double price;
  final int decimals;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final sigColor = signal.action.toSignalColor();
    final dirColor = prediction.direction.toSignalColor();
    final arrow = prediction.direction == 'UP' ? '▲' : prediction.direction == 'DOWN' ? '▼' : '◆';
    final pct = price == 0 ? 0.0 : (prediction.nextPrice - price) / price * 100;

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [sigColor.withValues(alpha: 0.12 + pulse.value * 0.06), AppColors.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: sigColor.withValues(alpha: 0.3 + pulse.value * 0.15)),
          boxShadow: [
            BoxShadow(
              color: sigColor.withValues(alpha: 0.08 + pulse.value * 0.08),
              blurRadius: 28 + pulse.value * 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SINYAL TRADING', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: sigColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(signal.strength.toUpperCase(), style: TextStyle(color: sigColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signal.action,
                      style: TextStyle(
                        color: sigColor,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        height: 1,
                        shadows: [Shadow(color: sigColor.withValues(alpha: 0.5), blurRadius: 20)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(_score2icon(signal.confidence), size: 15, color: sigColor),
                        const SizedBox(width: 4),
                        Text(
                          '${(signal.confidence * 100).toStringAsFixed(0)}% keyakinan',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(arrow, style: TextStyle(color: dirColor, fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(prediction.direction, style: TextStyle(color: dirColor, fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prediction.nextPrice.toStringAsFixed(decimals),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}% · ${prediction.horizon}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: signal.confidence),
                duration: const Duration(milliseconds: 800),
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceAlt,
                  color: sigColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _score2icon(double c) => c >= 0.75 ? Icons.local_fire_department_rounded : Icons.bolt_rounded;
}

class _QuickIndicators extends StatelessWidget {
  const _QuickIndicators({required this.ind});
  final Indicators ind;

  @override
  Widget build(BuildContext context) {
    final rsiColor = ind.rsi.value < 30
        ? AppColors.green
        : ind.rsi.value > 70
            ? AppColors.red
            : AppColors.amber;
    final macdColor = ind.macd.histogram >= 0 ? AppColors.green : AppColors.red;
    final emaColor = ind.ema.trend == 'bullish' ? AppColors.green : AppColors.red;

    return Row(
      children: [
        Expanded(child: _MiniIndicator(label: 'RSI', value: ind.rsi.value.toStringAsFixed(1), sub: ind.rsi.region, color: rsiColor)),
        const SizedBox(width: 8),
        Expanded(child: _MiniIndicator(label: 'MACD', value: ind.macd.histogram.toStringAsFixed(4), sub: ind.macd.cross ?? 'neutral', color: macdColor)),
        const SizedBox(width: 8),
        Expanded(child: _MiniIndicator(label: 'EMA', value: ind.ema.trend, sub: '', color: emaColor)),
      ],
    );
  }
}

class _MiniIndicator extends StatelessWidget {
  const _MiniIndicator({required this.label, required this.value, required this.sub, required this.color});

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10), overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

class _ChartPage extends StatelessWidget {
  const _ChartPage({required this.data});
  final TradingData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.candlestick_chart, size: 18, color: AppColors.blue),
                  const SizedBox(width: 8),
                  const Text('Price Chart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                    child: Text('${data.candles.length} candles', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CandleChart(candles: data.candles, decimals: data.decimals),
            ],
          ),
        ),
      ],
    );
  }
}

class _IndicatorsPage extends StatelessWidget {
  const _IndicatorsPage({required this.ind, required this.price});

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
            _IndicatorTile(icon: Icons.speed_rounded, label: 'SMA 20', value: ind.sma20.toStringAsFixed(2), sub: 'Harga: ${price.toStringAsFixed(2)}', color: AppColors.blue),
          ],
        ),
      ],
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

class _SentimentPage extends StatelessWidget {
  const _SentimentPage({required this.sentiment});
  final Sentiment sentiment;

  @override
  Widget build(BuildContext context) {
    final color = sentiment.label.toSignalColor();
    final isNews = sentiment.headlines.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Text('MARKET SENTIMENT', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.25)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 24)],
          ),
          child: Column(
            children: [
              _SentimentGauge(score: sentiment.score, label: sentiment.label, color: color),
              const SizedBox(height: 20),
              if (isNews) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('BERITA TERBARU', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ),
                const SizedBox(height: 10),
                for (final h in sentiment.headlines.take(4)) ...[
                  _NewsItem(headline: h, color: color),
                  const SizedBox(height: 6),
                ],
              ],
              const SizedBox(height: 10),
              Text(sentiment.source, style: const TextStyle(color: AppColors.textTertiary, fontSize: 10, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SentimentGauge extends StatelessWidget {
  const _SentimentGauge({required this.score, required this.label, required this.color});

  final double score;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 100,
          width: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: (score + 1) / 2,
                  strokeWidth: 8,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.toStringAsFixed(2),
                    style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewsItem extends StatelessWidget {
  const _NewsItem({required this.headline, required this.color});
  final String headline;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
