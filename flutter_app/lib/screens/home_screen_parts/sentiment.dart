part of 'package:cangcilung_trading/screens/home_screen.dart';

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
                  child: Text('BERITA TERBARU', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ),
                const SizedBox(height: 10),
                for (final h in sentiment.headlines.take(4)) ...[
                  _NewsItem(headline: h, color: color),
                  const SizedBox(height: 6),
                ],
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sentiment.confidence != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Keyakinan ${(sentiment.confidence! * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(sentiment.source, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ),
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
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
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
