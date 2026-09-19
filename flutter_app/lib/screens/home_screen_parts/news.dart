part of 'package:cangcilung_trading/screens/home_screen.dart';

class _NewsPage extends StatefulWidget {
  const _NewsPage({super.key, required this.sentiment, required this.api, required this.onRefresh});

  final Sentiment sentiment;
  final ApiService api;
  final Future<void> Function() onRefresh;

  @override
  State<_NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<_NewsPage> {
  final _calKey = GlobalKey<_CalendarSectionState>();

  Future<void> _refresh() async {
    await Future.wait([
      widget.onRefresh(),
      _calKey.currentState?.reload() ?? Future.value(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.blue,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _SentimentBlock(sentiment: widget.sentiment),
          const SizedBox(height: 24),
          _CalendarSection(key: _calKey, api: widget.api),
        ],
      ),
    );
  }
}