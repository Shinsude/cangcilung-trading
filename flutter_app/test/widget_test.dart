import 'package:flutter_test/flutter_test.dart';

import 'package:cangcilung_trading/models/models.dart';

void main() {
  test('TradingData parses valid JSON', () {
    final json = {
      'symbol': 'XAUUSD',
      'decimals': 2,
      'current_price': 4500.5,
      'change_pct': 0.4,
      'signal': {'action': 'BUY', 'strength': 'MODERATE', 'confidence': 0.7, 'score': 2.0, 'summary': 'test'},
      'prediction': {'next_price': 4510.0, 'horizon': '6H', 'direction': 'UP', 'confidence': 0.7, 'ensembles': 3},
      'indicators': {
        'rsi': {'value': 55.0, 'region': 'neutral'},
        'macd': {'value': 0.1, 'signal': 0.0, 'histogram': 0.1, 'cross': 'bullish'},
        'ema': {'ema9': 1, 'ema21': 1, 'ema50': 1, 'trend': 'bullish'},
        'bollinger': {'upper': 2, 'middle': 1, 'lower': 0, 'percent_b': 0.5},
        'sma20': 1.0,
        'volatility_20': 0.01,
      },
      'sentiment': {'score': 0.2, 'label': 'BULLISH', 'source': 'test', 'headlines': []},
      'candles': [
        {'t': '2026-01-01T00:00:00Z', 'o': 1.0, 'h': 1.1, 'l': 0.9, 'c': 1.05, 'v': 100},
      ],
    };
    final data = TradingData.fromJson(json);
    expect(data.symbol, 'XAUUSD');
    expect(data.signal.action, 'BUY');
    expect(data.prediction.direction, 'UP');
    expect(data.candles.length, 1);
  });
}