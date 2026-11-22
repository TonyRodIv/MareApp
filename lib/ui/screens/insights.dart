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
    final content = Stack(
      children: [
        const GlowBackground(height: 460),
        CollapsingTitleScope(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              PinnedCupertinoBar(
                height: 60,
                builder: (ctx, progress) => Row(
                  children: [
                    if (!embedded) const BackChevron() else const SizedBox(width: 44),
                    Expanded(child: BarTitle(title, progress: progress)),
                    trailing ?? const SizedBox(width: 44),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  Space.sm,
                  pad,
                  embedded ? navClearance(context) : Space.xl,
                ),
                sliver: SliverList.list(
                  children: [
                    LargeTitle(title, style: T.pageTitle),
                    if (subtitle != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        subtitle!,
                        style: T.label.copyWith(color: c.textSecondary),
                      ),
                    ],
                    const SizedBox(height: Space.lg),
                    ...children,
                  ],
                ),
              ),
            ],
          ),
        ),
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
          AppCard(
            child: Center(
              child: SizedBox(width: 220, child: CategoryWaffle(data: data)),
            ),
          ),
          ListGroup(
            title: 'Categorias',
            trailing: Text(
              fmtMoney(total, hidden: hidden),
              style: T.smallStrong.copyWith(color: c.textSecondary),
            ),
            children: [
              for (var i = 0; i < data.length; i++)
                Column(
                  children: [
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
                    const SizedBox(height: 8),
                    SpringBar(
                      fraction: data[i].value / total,
                      color: mono[i],
                      track: c.cardAlt,
                      height: 5,
                    ),
                  ],
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
                  padding: EdgeInsets.fromLTRB(pad, Space.lg, pad, Space.xl),
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

class RhythmScreen extends StatelessWidget {
  final bool embedded;
  const RhythmScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final cy = f.current;
    final today = f.todayAllowance;
    return _DetailPage(
      title: 'Ritmo do ciclo',
      subtitle:
          '${f.daysLeftInclToday} ${f.daysLeftInclToday == 1 ? 'dia restante' : 'dias restantes'} em ${cy.label()}',
      embedded: embedded,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pode gastar hoje',
                style: T.label.copyWith(color: c.textSecondary),
              ),
              CountingMoney(
                cents: today < 0 ? 0 : today,
                builder: (v) => MoneyText(v, hidden: hidden, style: T.display),
              ),
              const SizedBox(height: 6),
              Text(
                'Saldo livre de ${fmtMoney(f.freeBalance(cy), hidden: hidden)} dividido pelos dias que faltam. Se gastar menos hoje, sobra mais para amanhã.',
                style: T.small.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          title: 'Calendário do ciclo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CycleGrid(f: f, columns: 7),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _legend(context, c.palette.primary[200], 'Sem gastos'),
                  _legend(
                    context,
                    c.isDark ? c.palette.primary[500] : c.palette.primary[700],
                    'Dentro da meta',
                  ),
                  _legend(context, c.textTertiary, 'Passou da meta'),
                  _legend(context, c.accentWarm, 'Hoje'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Meta diária deste ciclo: ${fmtMoney(f.idealDaily(cy), hidden: hidden)}',
                style: T.small.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          titleWidget: Row(
            children: [
              Icon(LucideIcons.zap, color: c.accentWarm),
              const SizedBox(width: 8),
              Text(
                '${f.streak} ${f.streak == 1 ? 'dia' : 'dias'} de sequência',
                style: T.headline.copyWith(color: c.text),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeekStreak(f: f),
              const SizedBox(height: 12),
              Text(
                'Cada dia em que seus gastos do dia a dia ficam dentro da meta diária conta para a sequência. Gastos recorrentes não entram.',
                style: T.small.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        ListGroup(
          title: 'Resumo',
          gap: 12,
          children: [
            _line(context, 'Salário', f.salaryFor(cy), hidden),
            _line(context, 'Gastos recorrentes', -f.fixedTotal(cy), hidden),
            _line(
              context,
              'Aportes nas caixinhas',
              -f.contributionsTotal(cy),
              hidden,
            ),
            _line(context, 'Gastos do dia a dia', -f.variableTotal(cy), hidden),
            if (f.committed(cy) - f.fixedTotal(cy) - f.contributionsTotal(cy) !=
                0)
              _line(
                context,
                'Extras e resgates de caixinhas',
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
        width: 12,
        height: 12,
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
    final share = shareBase > 0 ? (total / shareBase).clamp(0.0, 1.0) : 0.0;

    return _DetailPage(
      title: 'Assinaturas',
      embedded: embedded,
      trailing: RoundIconButton(
        LucideIcons.plus,
        size: 40,
        label: 'Nova assinatura',
        bg: c.primary,
        fg: c.onPrimary,
        onTap: () => openAddExpense(context),
      ),
      children: [
        if (subs.isEmpty)
          EmptyState(
            icon: LucideIcons.tv,
            title: 'Nenhuma assinatura',
            message:
                'Adicione um gasto recorrente na categoria Assinaturas para acompanhar quanto seus serviços custam.',
            action: 'Adicionar',
            onAction: () => openAddExpense(context),
          )
        else ...[
          // Hero centralizado (mesmo ritmo de Extrato e Caixinhas)
          Center(
            child: Column(
              children: [
                Text(
                  'Custo mensal',
                  style: T.label.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.xs),
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
                  '${fmtMoney(total * 12, hidden: hidden)} por ano · ${subs.length} ${subs.length == 1 ? 'serviço' : 'serviços'}',
                  style: T.small.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.lg),

          // Gráfico em anel segmentado na cor tema de cada assinatura
          AppCard(
            title: 'Distribuição',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SubscriptionDonutChart(
                  subs: subs,
                  hidden: hidden,
                  onSelect: (e) => showExpenseActions(context, e),
                ),
                const SizedBox(height: Space.md),
                Text(
                  'Toque num serviço para destacar no gráfico ou toque novamente para abrir detalhes.',
                  style: T.small.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),

          // Resumo em 2 cards neutros com padding 16px
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AppCard(
                    title: 'Maior serviço',
                    expandChild: true,
                    onTap: () => showExpenseActions(context, subs.first),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        MoneyText(
                          subs.first.cents,
                          hidden: hidden,
                          style: T.cardValue,
                        ),
                        const SizedBox(height: Space.xxs),
                        Text(
                          subs.first.name,
                          style: T.small.copyWith(color: c.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: AppCard(
                    title: 'Peso no ciclo',
                    expandChild: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SpringBar(
                          fraction: share,
                          color: c.primary,
                          track: c.cardAlt,
                          height: 6,
                        ),
                        const SizedBox(height: Space.md),
                        Text(
                          '${(share * 100).round()}%',
                          style: T.cardValue.copyWith(color: c.text),
                        ),
                        const SizedBox(height: Space.xxs),
                        Text(
                          shareLabel,
                          style: T.small.copyWith(color: c.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          ListGroup(
            title: 'Serviços ativos',
            trailing: Text(
              fmtMoney(total, hidden: hidden),
              style: T.smallStrong.copyWith(color: c.textSecondary),
            ),
            children: [
              for (final e in subs) ExpenseRow(e: e, f: f, hidden: hidden),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Toque numa assinatura para editar ou parar de repetir.',
            textAlign: TextAlign.center,
            style: T.small.copyWith(color: c.textTertiary),
          ),
        ],
      ],
    );
  }
}

// ── Histórico ───────────────────────────────────────────────

class HistoryScreen extends StatelessWidget {
  final bool embedded;
  const HistoryScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final cycles = [
      for (final cy in f.lastCycles(12).reversed)
        if (f.salaryFor(cy) > 0 || f.expensesTotal(cy) > 0) cy,
    ];
    final fixedColor = c.primary;
    final varColor = c.primary.withValues(alpha: c.isDark ? 0.45 : 0.35);

    return _DetailPage(
      title: 'Histórico',
      subtitle: 'Calculado a partir dos seus lançamentos',
      embedded: embedded,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HistoryBars(
                f: f,
                cycles: isWide(context) ? 12 : 6,
                height: 180,
                hidden: hidden,
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  _dot(fixedColor),
                  Text(
                    ' Fixos e caixinhas   ',
                    style: T.small.copyWith(color: c.textSecondary),
                  ),
                  _dot(varColor),
                  Text(
                    ' Dia a dia',
                    style: T.small.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Widget _dot(Color c) => Container(
    width: 10,
    height: 10,
    decoration: ShapeDecoration(
      color: c,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(3)),
    ),
  );
}
