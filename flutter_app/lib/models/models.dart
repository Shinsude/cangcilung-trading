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

  Indicators({required this.rsi, required this.macd, required this.ema, required this.bollinger, required this.sma20, required this.volatility20});

  factory Indicators.fromJson(Map<String, dynamic> json) => Indicators(
        rsi: Rsi.fromJson(json['rsi'] as Map<String, dynamic>? ?? {}),
        macd: Macd.fromJson(json['macd'] as Map<String, dynamic>? ?? {}),
        ema: EmaSet.fromJson(json['ema'] as Map<String, dynamic>? ?? {}),
        bollinger: Bollinger.fromJson(json['bollinger'] as Map<String, dynamic>? ?? {}),
        sma20: (json['sma20'] as num?)?.toDouble() ?? 0,
        volatility20: (json['volatility_20'] as num?)?.toDouble() ?? 0,
      );
}

class Sentiment {
  final double score;
  final String label;
  final String source;
  final List<String> headlines;

  Sentiment({required this.score, required this.label, required this.source, required this.headlines});

  factory Sentiment.fromJson(Map<String, dynamic> json) => Sentiment(
        score: (json['score'] as num?)?.toDouble() ?? 0,
        label: json['label'] as String? ?? 'NEUTRAL',
        source: json['source'] as String? ?? '',
        headlines: ((json['headlines'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((h) => (h['headline'] as String?) ?? '')
            .toList(),
      );
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
  });

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
      );
}