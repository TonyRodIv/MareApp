import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
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
    final prev = f.byCategory(f.current.prev(s.data.cycleStartDay));
    final prevMap = {for (final e in prev) e.key.id: e.value};
    final mono = categoryMonochromeColors(c, data.length);
    return _DetailPage(
      title: 'Por categoria',
      subtitle: '${f.current.label()} · ${fmtMoney(total, hidden: hidden)}',
      embedded: embedded,
      children: [
        if (data.isEmpty)
          EmptyState(
            icon: LucideIcons.chartPie,
            title: 'Sem gastos neste ciclo',
            action: 'Adicionar gasto',
            onAction: () => openAddExpense(context),
          )
        else ...[
          // Hero alinhado à esquerda
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total em ${f.current.label()}',
                style: T.label.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: Space.xs),
              CountingMoney(
                cents: total,
                builder: (v) =>
                    MoneyText(v, hidden: hidden, style: T.displayLg),
              ),
            ],
          ),
          const SizedBox(height: Space.base),
          Builder(
            builder: (_) {
              final topCount = data.length > 4 ? 4 : data.length;
              final segs = <CapsuleSegment>[
                for (var i = 0; i < topCount; i++)
                  CapsuleSegment(
                    value: data[i].value.toDouble(),
                    color: mono[i],
                    label: data[i].key.label,
                  ),
                if (data.length > topCount)
                  CapsuleSegment(
                    value: data
                        .skip(topCount)
                        .fold<double>(0, (t, e) => t + e.value),
                    color: c.emptyCell,
                    label: 'Outros',
                  ),
              ];
              return SegmentedCapsuleBar(
                height: 36,
                gap: 4,
                segments: segs,
              );
            },
          ),
          ListGroup(
            title: 'Categorias',
            children: [
              for (var i = 0; i < data.length; i++)
                ListRow(
                  leading: IconBadge(data[i].key.icon, mono[i], size: 40),
                  title: data[i].key.label,
                  subtitle: _delta(
                    data[i].value,
                    prevMap[data[i].key.id],
                    hidden,
                  ),
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

  String _delta(int cur, int? prev, bool hidden) {
    if (prev == null || prev == 0) return 'Novo neste ciclo';
    final d = cur - prev;
    if (d == 0) return 'Igual ao ciclo anterior';
    return '${d > 0 ? '+' : '−'}${fmtMoney(d.abs(), hidden: hidden)} vs. ciclo anterior';
  }
}

/// Detalhe de categoria no mesmo padrão visual de `BoxDetail` (Caixinhas):
/// anel circular centralizado com participação no ciclo, ações rápidas em
/// botões circulares e lista dos lançamentos da categoria.
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
    final prevCy = cy.prev(s.data.cycleStartDay);

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

    final prevTotal = f
        .expensesIn(prevCy)
        .where((e) => e.categoryId == cat.id)
        .fold<int>(0, (t, e) => t + e.cents);
    final delta = _deltaText(total, prevTotal, hidden);
    final accent = c.tone(cat.color);
    final pad = sidePadding(context, maxWidth: 680);
    final avg = items.isEmpty ? 0 : (total / items.length).round();

    return SheetScaler(
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: Stack(
          children: [
            GlowBackground(
              tint: c.tone(cat.color, min: 2.5),
              height: 460,
            ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                PinnedCupertinoBar(
                  height: 60,
                  maxWidth: 680,
                  builder: (ctx, _) => Row(
                    children: [
                      const BackChevron(),
                      Expanded(
                        child: Text(
                          cat.label,
                          style: T.bodyStrong.copyWith(color: c.text),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      RoundIconButton(
                        LucideIcons.plus,
                        size: 44,
                        label: 'Novo gasto em ${cat.label}',
                        glass: true,
                        onTap: () => openAddExpense(
                          context,
                          initialCategoryId: cat.id,
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    pad,
                    Space.lg,
                    pad,
                    Space.xl + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.list(
                    children: [
                      // ── Hero circular centralizado (reutilizando padrão de Caixinhas)
                      Column(
                        children: [
                          SpringBuilder(
                            value: share,
                            from: 0,
                            spring: Springs.settle,
                            builder: (_, v, _) => ProgressRing(
                              size: 136,
                              stroke: 8,
                              fraction: v,
                              color: accent,
                              track: c.cardAlt,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: cat.color.withValues(
                                    alpha: c.isDark ? 0.18 : 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  cat.icon,
                                  size: 42,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.lg),
                          CountingMoney(
                            cents: total,
                            builder: (v) => MoneyText(
                              v,
                              hidden: hidden,
                              style: T.displayLg,
                            ),
                          ),
                          const SizedBox(height: Space.xs),
                          Text(
                            cycleTotal > 0
                                ? '${(share * 100).round()}% dos gastos de ${cy.label()}${delta != null ? ' · $delta' : ''}'
                                : 'Sem gastos em ${cy.label()}',
                            textAlign: TextAlign.center,
                            style: T.label.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.lg),

                      // ── Ações rápidas em botões circulares neutros
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          CircleAction(
                            icon: LucideIcons.plus,
                            label: 'Novo gasto',
                            onTap: () => openAddExpense(
                              context,
                              initialCategoryId: cat.id,
                            ),
                          ),
                          CircleAction(
                            icon: LucideIcons.receiptText,
                            label: 'No Extrato',
                            onTap: () {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                              shellNav.goTo(
                                1,
                                filter: ExtratoFilter(categoryId: cat.id),
                              );
                            },
                          ),
                        ],
                      ),

                      if (items.isEmpty) ...[
                        SectionHeader('Gastos em ${cy.label()}'),
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
                        ),
                      ] else ...[
                        ListGroup(
                          title: 'Gastos em ${cy.label()}',
                          trailing: Text(
                            '${items.length} ${items.length == 1 ? 'item' : 'itens'}',
                            style: T.smallStrong.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                          children: [
                            for (final e in items)
                              ExpenseRow(e: e, f: f, hidden: hidden),
                          ],
                        ),
                        const SizedBox(height: Space.base),
                        Text(
                          'Média de ${fmtMoney(avg, hidden: hidden)} por lançamento neste ciclo.',
                          textAlign: TextAlign.center,
                          style: T.small.copyWith(color: c.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _deltaText(int cur, int prev, bool hidden) {
    if (prev <= 0) return cur > 0 ? 'novo neste ciclo' : null;
    final d = cur - prev;
    if (d == 0) return 'igual ao anterior';
    return '${d > 0 ? '+' : '−'}${fmtMoney(d.abs(), hidden: hidden)} vs. anterior';
  }
}

// ── Ritmo do ciclo (Para hoje / Fim de semana / Sequência) ──

enum RhythmFocus { today, weekend }

class RhythmScreen extends StatefulWidget {
  final bool embedded;
  final RhythmFocus initialFocus;
  const RhythmScreen({
    super.key,
    this.embedded = false,
    this.initialFocus = RhythmFocus.today,
  });

  @override
  State<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends State<RhythmScreen> {
  late RhythmFocus _focus = widget.initialFocus;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final cy = f.current;
    final today = f.todayAllowance;
    final weekendDays = f.upcomingWeekend;
    final weekend = f.weekendAllowance;
    final ideal = f.idealDaily(cy);
    final isWeekend = _focus == RhythmFocus.weekend;

    return _DetailPage(
      title: 'Ritmo',
      embedded: widget.embedded,
      children: [
        Segmented<RhythmFocus>(
          value: _focus,
          options: const {
            RhythmFocus.today: 'Hoje',
            RhythmFocus.weekend: 'Fim de semana',
          },
          onChanged: (v) => setState(() => _focus = v),
        ),
        const SizedBox(height: Space.lg),

        // Hero alinhado à esquerda (foco em Hoje ou Fim de semana)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isWeekend
                  ? 'Para o fim de semana'
                  : (today < 0 ? 'Passou hoje' : 'Pode gastar hoje'),
              style: T.label.copyWith(
                color: !isWeekend && today < 0 ? c.negative : c.textSecondary,
              ),
            ),
            const SizedBox(height: Space.xs),
            if (isWeekend && weekendDays.isEmpty)
              Text('—', style: T.displayLg.copyWith(color: c.textSecondary))
            else
              CountingMoney(
                key: ValueKey(_focus),
                cents: isWeekend
                    ? (weekend < 0 ? 0 : weekend)
                    : (today < 0 ? -today : today),
                builder: (v) => MoneyText(
                  v,
                  hidden: hidden,
                  style: T.displayLg,
                  color: !isWeekend && today < 0 ? c.negative : null,
                ),
              ),
            const SizedBox(height: Space.xs),
            Text(
              isWeekend
                  ? (weekendDays.isEmpty
                        ? 'Sem fim de semana restante em ${cy.label()}'
                        : '${weekendDays.length == 1 ? '1 dia' : '${weekendDays.length} dias'} · Meta ${fmtMoney(ideal, hidden: hidden)}/dia · ${f.daysLeftInclToday}d no ciclo')
                  : 'Meta ${fmtMoney(ideal, hidden: hidden)}/dia · ${f.daysLeftInclToday} ${f.daysLeftInclToday == 1 ? 'dia restante' : 'dias restantes'}',
              style: T.small.copyWith(color: c.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),

        AppCard(
          title: 'Calendário de ${cy.label()}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CycleGrid(
                f: f,
                columns: 7,
                highlight: isWeekend ? weekendDays.toSet() : const {},
              ),
              const SizedBox(height: Space.md),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _legend(context, c.palette.primary[200], 'Sem gastos'),
                  _legend(
                    context,
                    c.isDark ? c.palette.primary[500] : c.palette.primary[700],
                    'Na meta',
                  ),
                  _legend(context, c.textTertiary, 'Acima'),
                  _legend(
                    context,
                    c.accentWarm,
                    isWeekend ? 'Fim de semana' : 'Hoje',
                  ),
                ],
              ),
            ],
          ),
        ),

        ListGroup(
          title: 'Resumo do ciclo',
          gap: 12,
          children: [
            _line(context, 'Salário', f.salaryFor(cy), hidden),
            _line(context, 'Fixos', -f.fixedTotal(cy), hidden),
            _line(context, 'Caixinhas', -f.contributionsTotal(cy), hidden),
            _line(context, 'Dia a dia', -f.variableTotal(cy), hidden),
            if (f.committed(cy) - f.fixedTotal(cy) - f.contributionsTotal(cy) !=
                0)
              _line(
                context,
                'Extras das caixinhas',
                -(f.committed(cy) -
                    f.fixedTotal(cy) -
                    f.contributionsTotal(cy)),
                hidden,
              ),
            _line(
              context,
              'Saldo livre',
              f.freeBalance(cy),
              hidden,
              strong: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: ShapeDecoration(
          color: color,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: T.small.copyWith(color: context.c.textSecondary)),
    ],
  );

  Widget _line(
    BuildContext context,
    String label,
    int v,
    bool hidden, {
    bool strong = false,
  }) {
    final c = context.c;
    return ListRow(
      title: label,
      titleColor: strong ? c.text : c.textSecondary,
      value: fmtMoney(v, hidden: hidden),
      valueColor: v < 0 && strong
          ? c.negative
          : (strong ? c.text : c.textSecondary),
      strong: strong,
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
      trailing: RoundIconButton(
        LucideIcons.plus,
        size: 44,
        label: 'Nova assinatura',
        bg: c.primary,
        fg: c.onPrimary,
        onTap: () => openAddExpense(context, initialCategoryId: 'assinaturas'),
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
          const SizedBox(height: Space.base),

          ListGroup(
            title: 'Serviços ativos',
            children: [
              for (final e in subs) ExpenseRow(e: e, f: f, hidden: hidden),
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

        if (cycles.isNotEmpty)
          ListGroup(
            title: 'Ciclos',
            gap: 18,
            children: [
              for (final cy in cycles)
                ListRow(
                  title: cy.label(),
                  subtitle:
                      '${sameDay(cy.start, f.current.start) ? 'Livre até agora · ' : ''}Gastos ${fmtMoney(f.expensesTotal(cy), hidden: hidden)} · Guardado ${fmtMoney(f.contributionsTotal(cy), hidden: hidden)}',
                  value: fmtMoney(f.freeBalance(cy), hidden: hidden),
                  valueColor: f.freeBalance(cy) < 0 ? c.negative : c.text,
                ),
            ],
          ),
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
