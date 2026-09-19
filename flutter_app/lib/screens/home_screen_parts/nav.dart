part of 'package:cangcilung_trading/screens/home_screen.dart';

class _TopBar extends StatelessWidget {
  const _TopBar({required this.symbols, required this.selected, required this.onSelect, required this.onRefresh, required this.live, this.simulated = false, required this.notifyOn, required this.onToggleNotify});

  final List<String> symbols;
  final String selected;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onRefresh;
  final bool live;
  final bool simulated;
  final bool notifyOn;
  final ValueChanged<bool> onToggleNotify;

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
              const Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cangcilung', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('TRADING AI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary, letterSpacing: 1.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
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
              IconButton(
                onPressed: () => unawaited(onRefresh()),
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 22),
                tooltip: 'Segarkan data',
              ),
              _NotifButton(on: notifyOn, onToggle: onToggleNotify),
              _LiveIndicator(live: live, simulated: simulated),
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
    return Tooltip(
      message: on ? 'Nonaktifkan notifikasi sinyal' : 'Aktifkan notifikasi sinyal',
      child: InkWell(
        onTap: () => onToggle(!on),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.25)),
          ),
          child: Icon(on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 18, color: c),
        ),
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.live, this.simulated = false});
  final bool live;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final label = live ? 'LIVE' : (simulated ? 'SIMULASI' : 'OFFLINE');
    final c = live ? AppColors.green : (simulated ? AppColors.amber : AppColors.textTertiary);
    return Tooltip(
      message: live
          ? 'Data langsung dari pasar'
          : (simulated ? 'Data simulasi — bukan untuk trading nyata' : 'Tidak ada data live'),
      child: AnimatedContainer(
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
              label,
              style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBar extends StatelessWidget {
  const _NoticeBar({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.amber, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onClose,
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, color: AppColors.amber),
            tooltip: 'Tutup',
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

  static const _icons = [Icons.auto_graph, Icons.newspaper, Icons.psychology_rounded];
  static const _labels = ['Sinyal', 'Berita', 'Model'];

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
                      fontSize: 11,
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
