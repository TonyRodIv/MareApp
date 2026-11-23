import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/charts.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'add_expense.dart';
import 'expense_sheet.dart';
import 'extrato.dart';
import 'shell.dart';

/// Esqueleto comum das telas de detalhe com top bar fixa + progressive blur.
/// Quando [embedded] é verdadeiro, renderiza como aba fixa dentro do `Shell`
/// (sem botão voltar e com respiro inferior para a navbar flutuante).
class _DetailPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final bool embedded;
  const _DetailPage({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pad = sidePadding(context);
    final scroll = CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        PinnedCupertinoBar(
          height: 60,
          builder: (ctx, progress) => Row(
            children: [
              if (embedded) ...[
                Expanded(
                  child: Text(
                    title,
                    style: T.pageTitle.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?trailing,
              ] else ...[
                const BackChevron(),
                Expanded(child: BarTitle(title, progress: progress)),
                trailing ?? const SizedBox(width: 44),
              ],
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            pad,
            embedded ? Space.base : Space.sm,
            pad,
            embedded
                ? navClearance(context)
                : Space.xl + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.list(
            children: [
              if (!embedded) ...[
                LargeTitle(title, style: T.pageTitle),
                const SizedBox(height: Space.lg),
              ],
              ...children,
            ],
          ),
        ),
      ],
    );
    final content = Stack(
      children: [
        const GlowBackground(height: 460),
        embedded ? scroll : CollapsingTitleScope(child: scroll),
      ],
    );
    if (embedded) return content;
    return SheetScaler(
      child: CupertinoPageScaffold(backgroundColor: c.bg, child: content),
    );
  }
}

// ── Categorias ──────────────────────────────────────────────

class CategoriesScreen extends StatelessWidget {
  final bool embedded;
  const CategoriesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final data = f.byCategory(f.current);
    final total = data.fold<int>(0, (t, e) => t + e.value);
    return _DetailPage(
      title: 'Por categoria',
      subtitle: '${f.current.label()} · ${fmtMoney(total, hidden: hidden)}',
      embedded: embedded,
      children: [
        if (data.isEmpty)
          EmptyState(
            icon: LucideIcons.chartPie,
            title: 'Sem gastos neste ciclo',
            message: 'Adicione um gasto para ver a divisão do seu ciclo por categoria.',
            action: 'Adicionar gasto',
            onAction: () => openAddExpense(context),
          )
        else ...[
          // Anel circular completo segmentado diretamente sobre o fundo
          Center(
            child: CategoryCircleGauge(
              items: data,
              hidden: hidden,
              footer: 'Total em ${f.current.label()}',
              onSelect: (cat) => push(
                context,
                CategoryDetailScreen(categoryId: cat.id),
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          ListGroup(
            children: [
              for (var i = 0; i < data.length; i++)
                ListRow(
                  leading: IconBadge(
                    data[i].key.icon,
                    c.tone(data[i].key.color),
                    size: 40,
                  ),
                  title: data[i].key.label,
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fmtMoney(data[i].value, hidden: hidden),
                        style: T.bodyMedium.copyWith(color: c.text),
                      ),
                      Text(
                        '${(data[i].value / total * 100).round()}%',
                        style: T.small.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                  arrow: true,
                  onTap: () => push(
                    context,
                    CategoryDetailScreen(categoryId: data[i].key.id),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Detalhe de categoria focado no valor e na lista de gastos do ciclo.
class CategoryDetailScreen extends StatelessWidget {
  final String categoryId;
  const CategoryDetailScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final cat = categoryById(categoryId);
    final cy = f.current;

    final items = f
        .expensesIn(cy)
        .where((e) => e.categoryId == cat.id)
        .toList()
      ..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.cents.compareTo(a.cents);
      });
    final total = items.fold<int>(0, (t, e) => t + e.cents);
    final cycleTotal = f.expensesTotal(cy);
    final share = cycleTotal > 0 ? (total / cycleTotal).clamp(0.0, 1.0) : 0.0;
    final pad = sidePadding(context, maxWidth: 680);

    return SheetScaler(
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: Stack(
          children: [
            GlowBackground(
              tint: c.tone(cat.color, min: 2.5),
              height: 440,
            ),
            CollapsingTitleScope(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  PinnedCupertinoBar(
                    height: 60,
                    maxWidth: 680,
                    builder: (ctx, progress) => Row(
                      children: [
                        const BackChevron(),
                        Expanded(
                          child: BarTitle(cat.label, progress: progress),
                        ),
                        Builder(
                          builder: (_) {
                            final (btnBg, btnFg) = softActionTone(
                              c.palette.primary[500],
                              isDark: c.isDark,
                            );
                            return RoundIconButton(
                              LucideIcons.plus,
                              size: 44,
                              label: 'Novo gasto em ${cat.label}',
                              bg: btnBg,
                              fg: btnFg,
                              onTap: () => openAddExpense(
                                context,
                                initialCategoryId: cat.id,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      Space.sm,
                      pad,
                      Space.xl + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverList.list(
                      children: [
                        LargeTitle(cat.label, style: T.pageTitle),
                        const SizedBox(height: Space.md),
                        // Hero enxuto alinhado à esquerda (foco no valor e na lista)
                        CountingMoney(
                          cents: total,
                          builder: (v) => MoneyText(
                            v,
                            hidden: hidden,
                            style: T.displayLg,
                          ),
                        ),
                        if (cycleTotal > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${(share * 100).round()}% dos gastos de ${cy.label()}',
                            style: T.small.copyWith(color: c.textSecondary),
                          ),
                        ],
                        const SizedBox(height: Space.lg),

                        if (items.isEmpty)
                          EmptyState(
                            icon: cat.icon,
                            title: 'Sem gastos nesta categoria',
                            message:
                                'Os lançamentos em ${cat.label} neste ciclo aparecem aqui.',
                            action: 'Adicionar gasto',
                            onAction: () => openAddExpense(
                              context,
                              initialCategoryId: cat.id,
                            ),
                          )
                        else
                          ListGroup(
                            children: [
                              for (final e in items)
                                ExpenseRow(
                                  e: e,
                                  f: f,
                                  hidden: hidden,
                                  hideCategory: true,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Assinaturas ─────────────────────────────────────────────

class SubscriptionsScreen extends StatelessWidget {
  final bool embedded;
  const SubscriptionsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final cy = f.current;
    final hidden = s.data.hideValues;
    final subs = f.subscriptions(cy);
    final total = subs.fold<int>(0, (t, e) => t + e.cents);
    final salary = f.salaryFor(cy);
    final totalExpenses = f.expensesTotal(cy);
    final shareBase = salary > 0 ? salary : totalExpenses;
    final shareLabel = salary > 0 ? 'do salário' : 'dos gastos';
    final rawShare = shareBase > 0 ? total / shareBase : 0.0;

    return _DetailPage(
      title: 'Assinaturas',
      embedded: embedded,
      trailing: Builder(
        builder: (_) {
          final (btnBg, btnFg) = softActionTone(
            c.palette.primary[500],
            isDark: c.isDark,
          );
          return RoundIconButton(
            LucideIcons.plus,
            size: 44,
            label: 'Nova assinatura',
            bg: btnBg,
            fg: btnFg,
            onTap: () =>
                openAddExpense(context, initialCategoryId: 'assinaturas'),
          );
        },
      ),
      children: [
        if (subs.isEmpty)
          EmptyState(
            icon: LucideIcons.tv,
            title: 'Nenhuma assinatura',
            message:
                'Adicione um gasto recorrente na categoria Assinaturas para acompanhar seus serviços.',
            action: 'Adicionar',
            onAction: () =>
                openAddExpense(context, initialCategoryId: 'assinaturas'),
          )
        else ...[
          // Arco aberto segmentado diretamente no fundo (sem container)
          Center(
            child: SubscriptionArcGauge(
              subs: subs,
              hidden: hidden,
              footer:
                  '${fmtMoney(total * 12, hidden: hidden)}/ano${shareBase > 0 ? ' · ${(rawShare * 100).round()}% $shareLabel' : ''}',
              onSelect: (e) => showExpenseActions(context, e),
            ),
          ),
          const SizedBox(height: Space.lg),

          ListGroup(
            children: [
              for (final e in subs)
                ExpenseRow(e: e, f: f, hidden: hidden, hideCategory: true),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Histórico ───────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  final bool embedded;
  const HistoryScreen({super.key, this.embedded = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _months = 6;
  bool _barsMode = false;
  int? _selectedIdx;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final list = f.lastCycles(_months);
    final activeIdx =
        _selectedIdx != null && _selectedIdx! < list.length
            ? _selectedIdx!
            : list.length - 1;
    final activeCycle = list[activeIdx];
    final activeTotal = f.expensesTotal(activeCycle);
    final prevCycle = activeIdx > 0
        ? list[activeIdx - 1]
        : activeCycle.prev(s.data.cycleStartDay);
    final prevTotal = f.expensesTotal(prevCycle);
    final deltaPct = prevTotal > 0
        ? ((activeTotal - prevTotal) / prevTotal * 100)
        : null;
    final cycles = [
      for (final cy in f.lastCycles(12).reversed)
        if (f.salaryFor(cy) > 0 || f.expensesTotal(cy) > 0) cy,
    ];
    final fixedColor = c.primary;
    final varColor = c.primary.withValues(alpha: c.isDark ? 0.45 : 0.35);

    return _DetailPage(
      title: 'Histórico',
      embedded: widget.embedded,
      children: [
        // Cabeçalho com valor + variação à esquerda e alternador linha/barras à direita
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeCycle.label(),
                    style: T.label.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: Space.xxs),
                  CountingMoney(
                    cents: activeTotal,
                    builder: (v) =>
                        MoneyText(v, hidden: hidden, style: T.displayLg),
                  ),
                  if (deltaPct != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          deltaPct > 0
                              ? LucideIcons.trendingUp
                              : LucideIcons.trendingDown,
                          size: 14,
                          color: deltaPct > 0 ? c.negative : c.positive,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${deltaPct > 0 ? '+' : ''}${deltaPct.toStringAsFixed(0)}% vs. ${prevCycle.shortLabel()}',
                          style: T.smallStrong.copyWith(
                            color: deltaPct > 0 ? c.negative : c.positive,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _modeBtn(
                  context,
                  icon: LucideIcons.trendingUp,
                  active: !_barsMode,
                  label: 'Gráfico em linha',
                  onTap: () => setState(() => _barsMode = false),
                ),
                const SizedBox(width: Space.xs),
                _modeBtn(
                  context,
                  icon: LucideIcons.chartColumn,
                  active: _barsMode,
                  label: 'Gráfico em barras',
                  onTap: () => setState(() => _barsMode = true),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Space.base),

        // Seletor de período (3M / 6M / 12M)
        Segmented<int>(
          value: _months,
          options: const {3: '3M', 6: '6M', 12: '12M'},
          onChanged: (v) => setState(() {
            _months = v;
            _selectedIdx = null;
          }),
        ),
        const SizedBox(height: Space.lg),

        // Gráfico diretamente sobre o fundo (sem container extra)
        if (!_barsMode)
          HistoryLineChart(
            f: f,
            cycles: _months,
            height: 204,
            hidden: hidden,
            onSelect: (idx) => setState(() => _selectedIdx = idx),
          )
        else ...[
          HistoryBars(
            f: f,
            cycles: _months,
            height: 196,
            hidden: hidden,
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.xs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(fixedColor),
                  Text(
                    ' Fixos e caixinhas',
                    style: T.small.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(varColor),
                  Text(
                    ' Dia a dia',
                    style: T.small.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ],

        if (cycles.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          ListGroup(
            gap: 18,
            children: [
              for (final cy in cycles)
                ListRow(
                  title: cy.label(),
                  subtitle:
                      'Gastos ${fmtMoney(f.expensesTotal(cy), hidden: hidden)}',
                  value: fmtMoney(f.freeBalance(cy), hidden: hidden),
                  valueColor: f.freeBalance(cy) < 0 ? c.negative : c.text,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _modeBtn(
    BuildContext context, {
    required IconData icon,
    required bool active,
    required String label,
    required VoidCallback onTap,
  }) {
    final c = context.c;
    return Pressable(
      semanticLabel: label,
      scale: 0.92,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? c.cardAlt : const Color(0x00000000),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: active ? c.text : c.textTertiary,
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 10,
    height: 10,
    decoration: ShapeDecoration(
      color: c,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(3)),
    ),
  );
}
