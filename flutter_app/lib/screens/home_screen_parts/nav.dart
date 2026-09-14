part of 'home_screen.dart';

class _TopBar extends StatelessWidget {
  const _TopBar({required this.symbols, required this.selected, required this.onSelect, required this.live, required this.notifyOn, required this.onToggleNotify, required this.minimal, required this.onToggleMinimal});

  final List<String> symbols;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool live;
  final bool notifyOn;
  final ValueChanged<bool> onToggleNotify;
  final bool minimal;
  final ValueChanged<bool> onToggleMinimal;

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
              IconButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => const _GuideSheet(),
                ),
                icon: const Icon(Icons.help_outline_rounded, color: AppColors.textSecondary, size: 22),
                tooltip: 'Cara Pakai',
              ),
              _NotifButton(on: notifyOn, onToggle: onToggleNotify),
              _MinimalButton(minimal: minimal, onToggle: onToggleMinimal),
              const SizedBox(width: 10),
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

class _NotifButton extends StatelessWidget {
  const _NotifButton({required this.on, required this.onToggle});
  final bool on;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = on ? AppColors.blue : AppColors.textTertiary;
    return GestureDetector(
      onTap: () => onToggle(!on),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Icon(on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 18, color: c),
      ),
    );
  }
}

class _MinimalButton extends StatelessWidget {
  const _MinimalButton({required this.minimal, required this.onToggle});
  final bool minimal;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = minimal ? AppColors.amber : AppColors.textTertiary;
    return GestureDetector(
      onTap: () => onToggle(!minimal),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Icon(minimal ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: c),
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
              boxShadow: live ? [const BoxShadow(color: AppColors.green, blurRadius: 8, spreadRadius: 1)] : null,
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

  static const _icons = [Icons.auto_graph, Icons.insights, Icons.event_rounded, Icons.newspaper, Icons.psychology_rounded];
  static const _labels = ['Signal', 'Indikator', 'Kalender', 'Sentimen', 'Model'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
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
