import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/report.dart';
import '../../services/report_service.dart';

// ─── Period Helpers ─────────────────────────────────────────────

enum ReportPeriod {
  today('today', 'Hari Ini'),
  week('week', 'Minggu'),
  month('month', 'Bulan'),
  year('year', 'Tahun');

  const ReportPeriod(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

String _formatPeriodRange(String from, String to) {
  try {
    final fromDate = DateTime.parse(from);
    final toDate = DateTime.parse(to);

    final isSameMonth =
        fromDate.year == toDate.year && fromDate.month == toDate.month;

    if (isSameMonth) {
      final dayStart = fromDate.day;
      final dayEnd = toDate.day;
      final monthYear = DateFormat('MMMM yyyy', 'id_ID').format(fromDate);
      return '$dayStart - $dayEnd $monthYear';
    }

    final fromStr = DateFormat('d MMM yyyy', 'id_ID').format(fromDate);
    final toStr = DateFormat('d MMM yyyy', 'id_ID').format(toDate);
    return '$fromStr - $toStr';
  } catch (_) {
    return '$from - $to';
  }
}

// ─── State Notifier for Period ──────────────────────────────────

class ReportPeriodNotifier extends StateNotifier<ReportPeriod> {
  ReportPeriodNotifier() : super(ReportPeriod.month);

  void setPeriod(ReportPeriod period) {
    if (state != period) state = period;
  }
}

final reportPeriodProvider =
    StateNotifierProvider<ReportPeriodNotifier, ReportPeriod>(
  (ref) => ReportPeriodNotifier(),
);

// ─── Async Providers ────────────────────────────────────────────

final summaryProvider = FutureProvider.family<ReportSummary, String>(
  (ref, period) async {
    final service = ref.read(reportServiceProvider);
    return service.getSummary(period: period);
  },
);

final breakdownProvider = FutureProvider.family<ReportBreakdown, String>(
  (ref, period) async {
    final service = ref.read(reportServiceProvider);
    return service.getBreakdown(period: period);
  },
);

// ─── Screen ─────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final period = ref.watch(reportPeriodProvider);

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(summaryProvider);
            ref.invalidate(breakdownProvider);
            // Re-fetch after invalidation
            ref.read(summaryProvider(period.apiValue).future);
            ref.read(breakdownProvider(period.apiValue).future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Text(
                    'Laporan',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Text(
                    'Ringkasan keuangan Anda',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

              // ── Period Selector ──
              SliverToBoxAdapter(
                child: _PeriodSelector(
                  selected: period,
                  onSelected: (p) {
                    ref.read(reportPeriodProvider.notifier).setPeriod(p);
                  },
                ),
              ),

              // ── Summary Card ──
              SliverToBoxAdapter(
                child: _SummarySection(
                  period: period.apiValue,
                ),
              ),

              // ── Breakdown Section ──
              SliverToBoxAdapter(
                child: _BreakdownSection(
                  period: period.apiValue,
                  tabController: _tabController,
                ),
              ),

              // ── Bottom padding ──
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Period Selector ────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onSelected,
  });

  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: ReportPeriod.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final period = ReportPeriod.values[index];
          final isSelected = period == selected;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: FilterChip(
              label: Text(
                period.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onSelected(period),
              backgroundColor: colorScheme.surfaceContainerHighest,
              selectedColor: colorScheme.primary,
              showCheckmark: false,
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        },
      ),
    );
  }
}

// ─── Summary Section ────────────────────────────────────────────

class _SummarySection extends ConsumerWidget {
  const _SummarySection({required this.period});

  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(summaryProvider(period));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: summaryAsync.when(
        loading: () => _SummaryCard.shimmer(context),
        error: (e, _) => _SummaryCard.error(context, '$e'),
        data: (summary) => _SummaryCard(
          periodFrom: summary.periodFrom,
          periodTo: summary.periodTo,
          income: summary.formattedIncome,
          expense: summary.formattedExpense,
          net: summary.formattedNet,
          netValue: summary.net,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.periodFrom,
    required this.periodTo,
    required this.income,
    required this.expense,
    required this.net,
    required this.netValue,
  });

  final String periodFrom;
  final String periodTo;
  final String income;
  final String expense;
  final String net;
  final int netValue;

  factory _SummaryCard.shimmer(BuildContext context) {
    return const _SummaryCard(
      periodFrom: '',
      periodTo: '',
      income: '',
      expense: '',
      net: '',
      netValue: 0,
    );
  }

  factory _SummaryCard.error(BuildContext context, String message) {
    return const _SummaryCard(
      periodFrom: '',
      periodTo: '',
      income: 'Error',
      expense: 'Error',
      net: 'Error',
      netValue: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isNetPositive = netValue >= 0;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period range
            if (periodFrom.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _formatPeriodRange(periodFrom, periodTo),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (periodFrom.isNotEmpty) const SizedBox(height: 16),

            // Income
            _SummaryRow(
              label: 'Pemasukan',
              value: income,
              icon: Icons.arrow_upward_rounded,
              iconColor: const Color(0xFF2E7D32),
              valueColor: const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 12),

            // Divider with subtle styling
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),

            // Expense
            _SummaryRow(
              label: 'Pengeluaran',
              value: expense,
              icon: Icons.arrow_downward_rounded,
              iconColor: colorScheme.error,
              valueColor: colorScheme.error,
            ),
            const SizedBox(height: 16),

            // Net
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mutasi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  net,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isNetPositive
                        ? const Color(0xFF2E7D32)
                        : colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ─── Breakdown Section ──────────────────────────────────────────

class _BreakdownSection extends ConsumerWidget {
  const _BreakdownSection({
    required this.period,
    required this.tabController,
  });

  final String period;
  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final breakdownAsync = ref.watch(breakdownProvider(period));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rincian per Kategori',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // Tab Toggle
          _BreakdownTabBar(
            tabController: tabController,
          ),
          const SizedBox(height: 16),

          // Content
          breakdownAsync.when(
            loading: () => _BreakdownList.shimmer(context),
            error: (e, _) => _BreakdownList.error(context, '$e'),
            data: (breakdown) {
              return AnimatedBuilder(
                animation: tabController,
                builder: (context, _) {
                  final isExpenseTab = tabController.index == 0;
                  final items = isExpenseTab
                      ? breakdown.expenseByCategory
                      : breakdown.incomeByCategory;

                  if (items.isEmpty) {
                    return _BreakdownList.empty(
                      context,
                      isExpenseTab ? 'pengeluaran' : 'pemasukan',
                    );
                  }

                  // Sort by total descending
                  final sorted = List<CategoryBreakdown>.from(items)
                    ..sort((a, b) => b.total.compareTo(a.total));

                  final maxTotal =
                      sorted.isNotEmpty ? sorted.first.total : 1;

                  return _BreakdownList(
                    items: sorted,
                    maxTotal: maxTotal,
                    isExpense: isExpenseTab,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BreakdownTabBar extends StatelessWidget {
  const _BreakdownTabBar({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: tabController,
        indicator: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(8),
        tabs: const [
          Tab(text: 'Pengeluaran'),
          Tab(text: 'Pemasukan'),
        ],
      ),
    );
  }
}

class _BreakdownList extends StatelessWidget {
  const _BreakdownList({
    required this.items,
    required this.maxTotal,
    required this.isExpense,
  });

  final List<CategoryBreakdown> items;
  final int maxTotal;
  final bool isExpense;

  static Widget shimmer(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _ShimmerItem(),
        ),
      ),
    );
  }

  static Widget empty(BuildContext context, String type) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada data $type',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Data akan muncul setelah ada transaksi',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  static Widget error(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: colorScheme.error.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'Gagal memuat data',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          _BreakdownItem(
            item: items[i],
            fraction: maxTotal > 0 ? items[i].total / maxTotal : 0,
            isExpense: isExpense,
            isLast: i == items.length - 1,
          ),
      ],
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  const _BreakdownItem({
    required this.item,
    required this.fraction,
    required this.isExpense,
    required this.isLast,
  });

  final CategoryBreakdown item;
  final double fraction;
  final bool isExpense;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final barColor =
        isExpense ? colorScheme.error.withValues(alpha: 0.7) : const Color(0xFF2E7D32);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category icon placeholder
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isExpense
                          ? Icons.category_rounded
                          : Icons.category_rounded,
                      size: 16,
                      color: barColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.category.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.count} transaksi',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.formattedTotal,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isExpense ? colorScheme.error : const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Background
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Fill
                        AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          widthFactor: fraction.clamp(0.0, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  barColor.withValues(alpha: 0.8),
                                  barColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerItem extends StatelessWidget {
  const _ShimmerItem();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 60,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 70,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
