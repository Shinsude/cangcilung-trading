class Candle {
  final String t;
  final double o, h, l, c;
  final int v;

  Candle({required this.t, required this.o, required this.h, required this.l, required this.c, required this.v});

  factory Candle.fromJson(Map<String, dynamic> json) => Candle(
        t: json['t'] as String? ?? '',
        o: (json['o'] as num?)?.toDouble() ?? 0,
        h: (json['h'] as num?)?.toDouble() ?? 0,
        l: (json['l'] as num?)?.toDouble() ?? 0,
        c: (json['c'] as num?)?.toDouble() ?? 0,
        v: (json['v'] as num?)?.toInt() ?? 0,
      );
}

class Prediction {
  final double nextPrice;
  final String horizon;
  final String direction;
  final double confidence;
  final int ensembles;

  Prediction({required this.nextPrice, required this.horizon, required this.direction, required this.confidence, required this.ensembles});

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
        nextPrice: (json['next_price'] as num?)?.toDouble() ?? 0,
        horizon: json['horizon'] as String? ?? '',
        direction: json['direction'] as String? ?? 'NEUTRAL',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        ensembles: (json['ensembles'] as num?)?.toInt() ?? 0,
      );
}

class Signal {
  final String action;
  final String strength;
  final double confidence;
  final double score;
  final String summary;

  Signal({required this.action, required this.strength, required this.confidence, required this.score, required this.summary});

  factory Signal.fromJson(Map<String, dynamic> json) => Signal(
        action: json['action'] as String? ?? 'HOLD',
        strength: json['strength'] as String? ?? 'WEAK',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        score: (json['score'] as num?)?.toDouble() ?? 0,
        summary: json['summary'] as String? ?? '',
      );
}

class Rsi {
  final double value;
  final String region;

  Rsi({required this.value, required this.region});

  factory Rsi.fromJson(Map<String, dynamic> json) => Rsi(
        value: (json['value'] as num?)?.toDouble() ?? 50,
        region: json['region'] as String? ?? 'neutral',
      );
}

class Macd {
  final double value;
  final double signal;
  final double histogram;
  final String? cross;

  Macd({required this.value, required this.signal, required this.histogram, this.cross});

  factory Macd.fromJson(Map<String, dynamic> json) => Macd(
        value: (json['value'] as num?)?.toDouble() ?? 0,
        signal: (json['signal'] as num?)?.toDouble() ?? 0,
        histogram: (json['histogram'] as num?)?.toDouble() ?? 0,
        cross: json['cross'] as String?,
      );
}

class EmaSet {
  final double ema9;
  final double ema21;
  final double ema50;
  final String trend;

  EmaSet({required this.ema9, required this.ema21, required this.ema50, required this.trend});

  factory EmaSet.fromJson(Map<String, dynamic> json) => EmaSet(
        ema9: (json['ema9'] as num?)?.toDouble() ?? 0,
        ema21: (json['ema21'] as num?)?.toDouble() ?? 0,
        ema50: (json['ema50'] as num?)?.toDouble() ?? 0,
        trend: json['trend'] as String? ?? 'neutral',
      );
}

class Bollinger {
  final double upper;
  final double middle;
  final double lower;
  final double? percentB;

  Bollinger({required this.upper, required this.middle, required this.lower, this.percentB});

  factory Bollinger.fromJson(Map<String, dynamic> json) => Bollinger(
        upper: (json['upper'] as num?)?.toDouble() ?? 0,
        middle: (json['middle'] as num?)?.toDouble() ?? 0,
        lower: (json['lower'] as num?)?.toDouble() ?? 0,
        percentB: (json['percent_b'] as num?)?.toDouble(),
      );
}

class Indicators {
  final Rsi rsi;
  final Macd macd;
  final EmaSet ema;
  final Bollinger bollinger;
  final double sma20;
  final double volatility20;
  final double? atr;

  Indicators({required this.rsi, required this.macd, required this.ema, required this.bollinger, required this.sma20, required this.volatility20, this.atr});

  factory Indicators.fromJson(Map<String, dynamic> json) => Indicators(
        rsi: Rsi.fromJson(json['rsi'] as Map<String, dynamic>? ?? {}),
        macd: Macd.fromJson(json['macd'] as Map<String, dynamic>? ?? {}),
        ema: EmaSet.fromJson(json['ema'] as Map<String, dynamic>? ?? {}),
        bollinger: Bollinger.fromJson(json['bollinger'] as Map<String, dynamic>? ?? {}),
        sma20: (json['sma20'] as num?)?.toDouble() ?? 0,
        volatility20: (json['volatility_20'] as num?)?.toDouble() ?? 0,
        atr: (json['atr'] as num?)?.toDouble(),
      );
}

class EconomicEvent {
  final String title;
  final String country;
  final String impact;
  final int ts;
  final String timeWib;

  const EconomicEvent({required this.title, required this.country, required this.impact, required this.ts, required this.timeWib});

  factory EconomicEvent.fromJson(Map<String, dynamic> json) => EconomicEvent(
        title: json['title'] as String? ?? '',
        country: (json['country'] as String? ?? '').toUpperCase(),
        impact: json['impact'] as String? ?? 'Medium',
        ts: (json['ts'] as num?)?.toInt() ?? 0,
        timeWib: json['time_wib'] as String? ?? '',
      );
}

class Sentiment {
  final double score;
  final String label;
  final String source;
  final double? confidence;
  final List<String> headlines;

  Sentiment({required this.score, required this.label, required this.source, this.confidence, required this.headlines});

  factory Sentiment.fromJson(Map<String, dynamic> json) => Sentiment(
        score: (json['score'] as num?)?.toDouble() ?? 0,
        label: json['label'] as String? ?? 'NEUTRAL',
        source: json['source'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble(),
        headlines: ((json['headlines'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((h) => (h['headline'] as String?) ?? '')
            .toList(),
      );
}

class Advanced {
  final String session;
  final String mtfD1Dir;
  final int mtfD1Score;
  final String mtfH4Dir;
  final int mtfH4Score;
  final String mtfH1Dir;
  final int mtfH1Score;
  final String mtfM30Dir;
  final int mtfM30Score;
  final String mtfM15Dir;
  final int mtfM15Score;
  final double mtfAlignment;
  final String mtfPrimary;
  final String regime;
  final String decompRegime;
  final String volatilityRegime;
  final double regimeAlignment;
  final String grade;
  final String stability;
  final String divergence;
  final String barLevel;
  final double trendConsistencyPct;
  final double cvdEfficiency;
  final bool smcWarning;
  final String riskLevel;
  final double weightedAlignment;
  final String rollUnderReco;
  final List<String> weaknesses;
  final bool isDeadZone;
  final bool mlRejected;
  final double confScore;
  final double cmpScore;
  final double chrScore;
  final double calScore;
  final double techScore;
  final double uniScore;

  const Advanced({
    this.session = 'UNKNOWN',
    this.mtfD1Dir = 'NEUTRAL',
    this.mtfD1Score = 0,
    this.mtfH4Dir = 'NEUTRAL',
    this.mtfH4Score = 0,
    this.mtfH1Dir = 'NEUTRAL',
    this.mtfH1Score = 0,
    this.mtfM30Dir = 'NEUTRAL',
    this.mtfM30Score = 0,
    this.mtfM15Dir = 'NEUTRAL',
    this.mtfM15Score = 0,
    this.mtfAlignment = 0,
    this.mtfPrimary = 'NEUTRAL',
    this.regime = 'NEUTRAL',
    this.decompRegime = 'RANGING',
    this.volatilityRegime = 'NORMAL',
    this.regimeAlignment = 0,
    this.grade = 'C',
    this.stability = 'UNKNOWN',
    this.divergence = 'NONE',
    this.barLevel = 'UNKNOWN',
    this.trendConsistencyPct = 50,
    this.cvdEfficiency = 0.5,
    this.smcWarning = false,
    this.riskLevel = 'LOW',
    this.weightedAlignment = 0,
    this.rollUnderReco = 'HOLD',
    this.weaknesses = const [],
    this.isDeadZone = false,
    this.mlRejected = false,
    this.confScore = 0,
    this.cmpScore = 0,
    this.chrScore = 0,
    this.calScore = 0,
    this.techScore = 0,
    this.uniScore = 0,
  });

  factory Advanced.fromJson(Map<String, dynamic> json) => Advanced(
        session: json['session'] as String? ?? 'UNKNOWN',
        mtfD1Dir: (json['mtf_d1_dir'] as String? ?? 'NEUTRAL').toUpperCase(),
        mtfD1Score: (json['mtf_d1_score'] as num?)?.toInt() ?? 0,
        mtfH4Dir: (json['mtf_h4_dir'] as String? ?? 'NEUTRAL').toUpperCase(),
        mtfH4Score: (json['mtf_h4_score'] as num?)?.toInt() ?? 0,
        mtfH1Dir: (json['mtf_h1_dir'] as String? ?? 'NEUTRAL').toUpperCase(),
        mtfH1Score: (json['mtf_h1_score'] as num?)?.toInt() ?? 0,
        mtfM30Dir: (json['mtf_m30_dir'] as String? ?? 'NEUTRAL').toUpperCase(),
        mtfM30Score: (json['mtf_m30_score'] as num?)?.toInt() ?? 0,
        mtfM15Dir: (json['mtf_m15_dir'] as String? ?? 'NEUTRAL').toUpperCase(),
        mtfM15Score: (json['mtf_m15_score'] as num?)?.toInt() ?? 0,
        mtfAlignment: (json['mtf_alignment'] as num?)?.toDouble() ?? 0,
        mtfPrimary: (json['mtf_primary'] as String? ?? 'NEUTRAL').toUpperCase(),
        regime: (json['regime'] as String? ?? 'NEUTRAL').toUpperCase(),
        decompRegime: (json['decomp_regime'] as String? ?? 'RANGING').toUpperCase(),
        volatilityRegime: (json['volatility_regime'] as String? ?? 'NORMAL').toUpperCase(),
        regimeAlignment: (json['regime_alignment'] as num?)?.toDouble() ?? 0,
        grade: (json['grade'] as String? ?? 'C').toUpperCase(),
        stability: (json['stability'] as String? ?? 'UNKNOWN').toUpperCase(),
        divergence: (json['divergence'] as String? ?? 'NONE').toUpperCase(),
        barLevel: (json['bar_level'] as String? ?? 'UNKNOWN').toUpperCase(),
        trendConsistencyPct: (json['trend_consistency_pct'] as num?)?.toDouble() ?? 50,
        cvdEfficiency: (json['cvd_efficiency'] as num?)?.toDouble() ?? 0.5,
        smcWarning: json['smc_warning'] as bool? ?? false,
        riskLevel: (json['risk_level'] as String? ?? 'LOW').toUpperCase(),
        weightedAlignment: (json['weighted_alignment'] as num?)?.toDouble() ?? 0,
        rollUnderReco: (json['roll_under_reco'] as String? ?? 'HOLD').toUpperCase(),
        weaknesses: ((json['weaknesses'] as List?) ?? const []).whereType<String>().toList(),
        isDeadZone: json['is_dead_zone'] as bool? ?? false,
        mlRejected: json['ml_rejected'] as bool? ?? false,
        confScore: (json['conf_score'] as num?)?.toDouble() ?? 0,
        cmpScore: (json['cmp_score'] as num?)?.toDouble() ?? 0,
        chrScore: (json['chr_score'] as num?)?.toDouble() ?? 0,
        calScore: (json['cal_score'] as num?)?.toDouble() ?? 0,
        techScore: (json['tech_score'] as num?)?.toDouble() ?? 0,
        uniScore: (json['uni_score'] as num?)?.toDouble() ?? 0,
      );
}

class PositionPlan {
  final bool open;
  final String side;
  final double entryPrice;
  final double currentPrice;
  final double stopLoss;
  final double takeProfit;
  final double points;
  final double pnlPct;
  final double distStopPct;
  final double distTpPct;
  final double? trailLevel;
  final bool trailActive;
  final double profitLockedPct;
  final String status;
  final String openedAt;

  const PositionPlan({
    this.open = false,
    this.side = '',
    this.entryPrice = 0,
    this.currentPrice = 0,
    this.stopLoss = 0,
    this.takeProfit = 0,
    this.points = 0,
    this.pnlPct = 0,
    this.distStopPct = 0,
    this.distTpPct = 0,
    this.trailLevel,
    this.trailActive = false,
    this.profitLockedPct = 0,
    this.status = 'OPEN',
    this.openedAt = '',
  });

  factory PositionPlan.fromJson(Map<String, dynamic> json) => PositionPlan(
        open: json['open'] as bool? ?? false,
        side: (json['side'] as String? ?? '').toUpperCase(),
        entryPrice: (json['entry_price'] as num?)?.toDouble() ?? 0,
        currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0,
        stopLoss: (json['stop_loss'] as num?)?.toDouble() ?? 0,
        takeProfit: (json['take_profit'] as num?)?.toDouble() ?? 0,
        points: (json['points'] as num?)?.toDouble() ?? 0,
        pnlPct: (json['pnl_pct'] as num?)?.toDouble() ?? 0,
        distStopPct: (json['dist_stop_pct'] as num?)?.toDouble() ?? 0,
        distTpPct: (json['dist_tp_pct'] as num?)?.toDouble() ?? 0,
        trailLevel: (json['trail_level'] as num?)?.toDouble(),
        trailActive: json['trail_active'] as bool? ?? false,
        profitLockedPct: (json['profit_locked_pct'] as num?)?.toDouble() ?? 0,
        status: (json['status'] as String? ?? 'OPEN').toUpperCase(),
        openedAt: json['opened_at'] as String? ?? '',
      );
}

class PipelineStats {
  final int tracked;
  final double entryRate;
  final double holdRate;
  final double rejectionRate;
  final double deadZoneRate;
  final double mlRejectRate;
  final double avgConfidence;
  final Map<String, int> gradeDistribution;
  final Map<String, int> directionCounts;

  const PipelineStats({
    this.tracked = 0,
    this.entryRate = 0,
    this.holdRate = 0,
    this.rejectionRate = 0,
    this.deadZoneRate = 0,
    this.mlRejectRate = 0,
    this.avgConfidence = 0,
    this.gradeDistribution = const {},
    this.directionCounts = const {},
  });

  factory PipelineStats.fromJson(Map<String, dynamic> json) {
    Map<String, int> toIntMap(Map<String, dynamic>? m) => (m ?? const {})
        .map((k, v) => MapEntry(k, (v as num).toInt()));
    return PipelineStats(
      tracked: (json['tracked'] as num?)?.toInt() ?? 0,
      entryRate: (json['entry_rate'] as num?)?.toDouble() ?? 0,
      holdRate: (json['hold_rate'] as num?)?.toDouble() ?? 0,
      rejectionRate: (json['rejection_rate'] as num?)?.toDouble() ?? 0,
      deadZoneRate: (json['dead_zone_rate'] as num?)?.toDouble() ?? 0,
      mlRejectRate: (json['ml_reject_rate'] as num?)?.toDouble() ?? 0,
      avgConfidence: (json['avg_confidence'] as num?)?.toDouble() ?? 0,
      gradeDistribution: toIntMap(json['grade_distribution'] as Map<String, dynamic>?),
      directionCounts: toIntMap(json['direction_counts'] as Map<String, dynamic>?),
    );
  }
}

class TradingData {
  final String symbol;
  final String name;
  final String category;
  final int decimals;
  final double currentPrice;
  final double previousClose;
  final double changePct;
  final Prediction prediction;
  final Signal signal;
  final Indicators indicators;
  final Sentiment sentiment;
  final List<Candle> candles;
  final Map<String, double> weights;
  final Risk risk;
  final PositionPlan position;
  final PipelineStats pipeline;
  final Advanced advanced;
  final SystemHealth? system;
  final DateTime? updatedAt;

  TradingData({
    required this.symbol,
    required this.name,
    required this.category,
    required this.decimals,
    required this.currentPrice,
    required this.previousClose,
    required this.changePct,
    required this.prediction,
    required this.signal,
    required this.indicators,
    required this.sentiment,
    required this.candles,
    this.weights = const {},
    Risk? risk,
    PositionPlan? position,
    PipelineStats? pipeline,
    Advanced? advanced,
    this.updatedAt,
    this.system,
  })  : risk = risk ?? const Risk(),
        position = position ?? const PositionPlan(),
        pipeline = pipeline ?? const PipelineStats(),
        advanced = advanced ?? const Advanced();

  factory TradingData.fromJson(Map<String, dynamic> json) => TradingData(
        symbol: json['symbol'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        decimals: (json['decimals'] as num?)?.toInt() ?? 2,
        currentPrice: (json['current_price'] as num?)?.toDouble() ?? 0,
        previousClose: (json['previous_close'] as num?)?.toDouble() ?? 0,
        changePct: (json['change_pct'] as num?)?.toDouble() ?? 0,
        prediction: Prediction.fromJson(json['prediction'] as Map<String, dynamic>? ?? {}),
        signal: Signal.fromJson(json['signal'] as Map<String, dynamic>? ?? {}),
        indicators: Indicators.fromJson(json['indicators'] as Map<String, dynamic>? ?? {}),
        sentiment: Sentiment.fromJson(json['sentiment'] as Map<String, dynamic>? ?? {}),
        candles: ((json['candles'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Candle.fromJson)
            .toList(),
        weights: ((json['weights'] as Map<String, dynamic>?) ?? const {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        risk: Risk.fromJson(json['risk'] as Map<String, dynamic>? ?? {}),
        position: PositionPlan.fromJson(json['position'] as Map<String, dynamic>? ?? {}),
        pipeline: PipelineStats.fromJson(json['pipeline'] as Map<String, dynamic>? ?? {}),
        advanced: Advanced.fromJson(json['advanced'] as Map<String, dynamic>? ?? {}),
        system: SystemHealth.fromJson(json['system'] as Map<String, dynamic>? ?? {}),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );
}

class SystemHealth {
  final double minimumStop;
  final double riskReward;
  final SafetyBounds safety;

  const SystemHealth({
    this.tsIntrinsic = 0,
    this.tsSnr = 0,
    this.decompRegime = 'NO DATA',
    this.barTotal = 0,
    this.theta = const Theta(),
    this.safety = const SafetyBounds(),
  });

  factory SystemHealth.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const {};
    return SystemHealth(
      tsIntrinsic: (j['ts_intrinsic'] as num?)?.toDouble() ?? 0,
      tsSnr: (j['ts_snr'] as num?)?.toDouble() ?? 0,
      decompRegime: (j['decomp_regime'] as String? ?? 'NO DATA').toUpperCase(),
      barTotal: (j['bar_total'] as num?)?.toInt() ?? 0,
      theta: Theta.fromJson(j['theta'] as Map<String, dynamic>?),
      safety: SafetyBounds.fromJson(j['safety'] as Map<String, dynamic>?) ??
          SafetyBounds.fromJson(_payload()['safety'] as Map<String, dynamic>?),
    );
  }
}

class Theta {
  final int aiDir;
  final int rulesDir;
  final double momentumPct;
  final bool aligned;
  final String label;

  const Theta({this.aiDir = 0, this.rulesDir = 0, this.momentumPct = 0, this.aligned = false, this.label = 'NEUTRAL'});

  factory Theta.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const {};
    return Theta(
      aiDir: (j['ai_dir'] as num?)?.toInt() ?? 0,
      rulesDir: (j['rules_dir'] as num?)?.toInt() ?? 0,
      momentumPct: (j['momentum_pct'] as num?)?.toDouble() ?? 0,
      aligned: (j['aligned'] as bool?) ?? false,
      label: (j['label'] as String? ?? 'NEUTRAL').toUpperCase(),
    );
  }
}

class SafetyBounds {
  final String status;
  final int violations;
  final double minimumStop;
  final double riskReward;

  const SafetyBounds({this.status = 'N/A', this.violations = 0, this.minimumStop = 0, this.riskReward = 0});

  factory SafetyBounds.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const {};
    return SafetyBounds(
      status: (j['status'] as String? ?? 'N/A').toUpperCase(),
      violations: (j['violations'] as num?)?.toInt() ?? 0,
      minimumStop: (j['minimum_stop'] as num?)?.toDouble() ?? 0,
      riskReward: (j['risk_reward'] as num?)?.toDouble() ?? 0,
    );
  }
}
}

class Risk {
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final double atr;
  final double riskReward;
  final String? side;
  final String? note;

  const Risk({this.entry = 0, this.stopLoss = 0, this.takeProfit = 0, this.atr = 0, this.riskReward = 0, this.side, this.note});

  bool get available => side != null && stopLoss > 0 && takeProfit > 0;

  factory Risk.fromJson(Map<String, dynamic> json) => Risk(
        entry: (json['entry'] as num?)?.toDouble() ?? 0,
        stopLoss: (json['stop_loss'] as num?)?.toDouble() ?? 0,
        takeProfit: (json['take_profit'] as num?)?.toDouble() ?? 0,
        atr: (json['atr'] as num?)?.toDouble() ?? 0,
        riskReward: (json['risk_reward'] as num?)?.toDouble() ?? 0,
        side: json['side'] as String?,
        note: json['note'] as String?,
      );
}

class AccWindow {
  final int window;
  final double winRate;
  final int trades;
  final double totalReturn;
  final double maxDrawdown;

  AccWindow({required this.window, required this.winRate, required this.trades, required this.totalReturn, required this.maxDrawdown});

  factory AccWindow.fromJson(Map<String, dynamic> json) => AccWindow(
        window: (json['window'] as num?)?.toInt() ?? 0,
        winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
        trades: (json['trades'] as num?)?.toInt() ?? 0,
        totalReturn: (json['total_return'] as num?)?.toDouble() ?? 0,
        maxDrawdown: (json['max_drawdown'] as num?)?.toDouble() ?? 0,
      );
}

class BacktestSummary {
  final double winRate;
  final double profitFactor;
  final double totalReturn;
  final double maxDrawdown;
  final int trades;
  final double quality;

  BacktestSummary({required this.winRate, required this.profitFactor, required this.totalReturn, required this.maxDrawdown, required this.trades, required this.quality});

  factory BacktestSummary.fromJson(Map<String, dynamic> json) => BacktestSummary(
        winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
        profitFactor: (json['profit_factor'] as num?)?.toDouble() ?? 0,
        totalReturn: (json['total_return'] as num?)?.toDouble() ?? 0,
        maxDrawdown: (json['max_drawdown'] as num?)?.toDouble() ?? 0,
        trades: (json['trades'] as num?)?.toInt() ?? 0,
        quality: (json['quality'] as num?)?.toDouble() ?? 0,
      );
}

class ModelStats {
  final String trainedAt;
  final Map<String, double> weights;
  final BacktestSummary backtest;
  final Map<String, AccWindow> accuracy;
  final int realSamples;
  final double? realWinRate;

  ModelStats({required this.trainedAt, required this.weights, required this.backtest, required this.accuracy, this.realSamples = 0, this.realWinRate});

  factory ModelStats.fromJson(Map<String, dynamic> json) {
    final bt = json['backtest'] as Map<String, dynamic>? ?? {};
    final acc = (json['rolling_accuracy'] as Map<String, dynamic>?) ?? const {};
    final real = (json['real_accuracy'] as Map<String, dynamic>?) ?? const {};
    return ModelStats(
      trainedAt: json['trained_at'] as String? ?? '',
      weights: ((json['weights'] as Map<String, dynamic>?) ?? const {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      backtest: BacktestSummary.fromJson(bt),
      accuracy: acc.map((k, v) => MapEntry(k, AccWindow.fromJson(v as Map<String, dynamic>? ?? {}))),
      realSamples: (real['samples'] as num?)?.toInt() ?? 0,
      realWinRate: (real['win_rate'] as num?)?.toDouble(),
    );
  }
}

class ModelInfo {
  final String strategy;
  final Map<String, ModelStats> symbols;

  ModelInfo({required this.strategy, required this.symbols});

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    final sym = (json['symbols'] as Map<String, dynamic>?) ?? const {};
    return ModelInfo(
      strategy: json['strategy'] as String? ?? '',
      symbols: sym.map((k, v) => MapEntry(k, ModelStats.fromJson(v as Map<String, dynamic>? ?? {}))),
    );
  }
}

class BacktestResponse {
  final String symbol;
  final BacktestSummary tuned;
  final BacktestSummary baseline;

  BacktestResponse({required this.symbol, required this.tuned, required this.baseline});

  factory BacktestResponse.fromJson(Map<String, dynamic> json) {
    final tuned = json['tuned'] as Map<String, dynamic>? ?? {};
    final baseline = json['default'] as Map<String, dynamic>? ?? {};
    return BacktestResponse(
      symbol: json['symbol'] as String? ?? '',
      tuned: BacktestSummary.fromJson(tuned),
      baseline: BacktestSummary.fromJson(baseline),
    );
  }
}
