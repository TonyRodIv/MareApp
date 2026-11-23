import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/finance.dart';
import '../../data/store.dart';
import '../widgets/charts.dart';
import '../widgets/dashboard.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'add_expense.dart';
import 'box_form.dart';
import 'cards.dart';
import 'extrato.dart';
import 'insights.dart';
import 'profile.dart';
import 'shell.dart';

enum HeroView { free, expenses, boxes }

/// Carteira (Figma 376:8447 / 391:1987).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HeroView _view = HeroView.free;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final cy = f.current;
    final hidden = s.data.hideValues;
    final name = s.data.userName.trim().split(' ').first;
    final noSalary = f.salary == 0;
    final hasCards = s.data.cards.isNotEmpty;
    final hasSubs = f.subscriptions(cy).isNotEmpty;

    return Stack(
      children: [
        const GlowBackground(height: 560),
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            PinnedCupertinoBar(
              height: 68,
              maxWidth: 1200,
              builder: (ctx, _) => Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Olá,' : 'Olá $name,',
                          style: T.headline.copyWith(color: c.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _greeting(),
                          style: T.small.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  RoundIconButton(
                    hidden ? LucideIcons.eyeOff : LucideIcons.eye,
                    size: 44,
                    label: hidden ? 'Mostrar valores' : 'Ocultar valores',
                    glass: true,
                    onTap: s.toggleHideValues,
                  ),
                  const SizedBox(width: Space.sm),
                  Pressable(
                    semanticLabel: 'Seu perfil',
                    onTap: () => ShellScope.of(context)?.goTo(3),
                    child: Avatar(
                      path: s.data.avatarPath,
                      name: s.data.userName,
                      size: 44,
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                sidePadding(context, maxWidth: 1200),
                36,
                sidePadding(context, maxWidth: 1200),
                Space.base,
              ),
              sliver: SliverToBoxAdapter(child: _hero(context, f, hidden)),
            ),
            // ── Cartões (ocultos por padrão na Carteira; ativáveis em "Editar grade")
            if (hasCards && !_effectiveHidden(s).contains('contas'))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: CardsStrip(
                    hidden: hidden,
                    leftPadding: sidePadding(context, maxWidth: 1200),
                    rightPadding: sidePadding(context, maxWidth: 1200),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                sidePadding(context, maxWidth: 1200),
                0,
                sidePadding(context, maxWidth: 1200),
                navClearance(context),
              ),
              sliver: SliverList.list(
                children: [
                  // ── Ações rápidas (cada botão usa uma cor do tema adaptada ao modo claro/escuro)
                  Builder(
                    builder: (_) {
                      final (expBg, expFg) = softActionTone(
                        c.palette.companion[500],
                        isDark: c.isDark,
                      );
                      final (boxBg, boxFg) = softActionTone(
                        c.palette.primary[500],
                        isDark: c.isDark,
                      );
                      return Row(
                        children: [
                          Expanded(
                            child: PillButton(
                              'Gastos',
                              icon: LucideIcons.receipt,
                              background: expBg,
                              foreground: expFg,
                              onTap: () => openAddExpense(context),
                            ),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: PillButton(
                              'Caixinhas',
                              icon: LucideIcons.piggyBank,
                              background: boxBg,
                              foreground: boxFg,
                              onTap: () => pushFluid(context, const BoxForm()),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: Space.md),

                  if (noSalary) ...[
                    AppCard(
                      onTap: () => editSalary(context),
                      color: c.primary,
                      child: Row(
                        children: [
                          Icon(LucideIcons.banknote, color: c.onPrimary),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Text(
                              'Informe seu salário para ver quanto dá para gastar por dia.',
                              style: T.label.copyWith(color: c.onPrimary),
                            ),
                          ),
                          Icon(
                            LucideIcons.arrowUpRight,
                            color: c.onPrimary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.md),
                  ],

                  // ── Cards adaptáveis (personalizáveis no botão "Editar grade")
                  DashboardGrid(
                    gap: Space.md,
                    spans: s.data.cardSpans,
                    onSpanChanged: s.setCardSpan,
                    tiles: _orderedVisibleTiles(
                      context,
                      f,
                      hidden,
                      noSalary,
                      hasSubs,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Center(
                    child: PillButton(
                      'Editar grade',
                      icon: LucideIcons.slidersHorizontal,
                      kind: BtnKind.ghost,
                      expand: false,
                      height: 44,
                      onTap: () => _editGrid(context, noSalary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const _widgetMeta = <String, (String, IconData, int)>{
    'contas': ('Contas e cartões', LucideIcons.landmark, 2),
    'gastos': ('Seus Gastos', LucideIcons.receipt, 1),
    'caixinhas': ('Caixinhas', LucideIcons.piggyBank, 1),
    'categorias': ('Por categoria', LucideIcons.chartPie, 2),
    'hoje': ('Para hoje', LucideIcons.calendarCheck, 1),
    'fds': ('Fim de semana', LucideIcons.sun, 1),
    'projecao': ('Projeção do ciclo', LucideIcons.trendingUp, 2),
    'assinaturas': ('Assinaturas', LucideIcons.tv, 2),
    'historico': ('Histórico visual', LucideIcons.chartColumn, 2),
  };

  /// Por padrão, a tela inicial mostra apenas os 5 widgets essenciais (contas
  /// e extras ficam ocultos até serem ativados em "Editar grade").
  static const _defaultHidden = <String>{
    'contas',
    'projecao',
    'assinaturas',
    'historico',
  };

  Set<String> _effectiveHidden(Store s) {
    if (s.data.widgetOrder.isEmpty && s.data.hiddenWidgets.isEmpty) {
      return {..._defaultHidden};
    }
    final out = s.data.hiddenWidgets.toSet();
    if (!s.data.widgetOrder.contains('contas')) {
      out.add('contas');
    }
    return out;
  }

  List<String> _allIds(List<String> savedOrder) {
    final defaults = _widgetMeta.keys.toList();
    final ordered = [
      for (final id in savedOrder)
        if (_widgetMeta.containsKey(id)) id,
      for (final id in defaults)
        if (!savedOrder.contains(id)) id,
    ];
    return ordered;
  }

  List<DashTile> _orderedVisibleTiles(
    BuildContext context,
    Finance f,
    bool hidden,
    bool noSalary,
    bool hasSubs,
  ) {
    final s = context.store;
    final cy = f.current;
    final hiddenSet = _effectiveHidden(s);
    final order = _allIds(s.data.widgetOrder);
    final tiles = <DashTile>[];

    for (final id in order) {
      if (hiddenSet.contains(id)) continue;
      if (noSalary && (id == 'hoje' || id == 'fds' || id == 'projecao')) {
        continue;
      }
      if (id == 'categorias' &&
          f.byCategory(cy).isEmpty &&
          !s.data.widgetOrder.contains('categorias')) {
        continue;
      }
      if (id == 'assinaturas' &&
          !hasSubs &&
          !s.data.widgetOrder.contains('assinaturas')) {
        continue;
      }

      switch (id) {
        case 'contas':
          continue; // Renderizado na faixa superior CardsStrip
        case 'gastos':
          final spent = f.expensesTotal(cy);
          final sal = f.salaryFor(cy);
          final prevSpent = f.expensesTotal(cy.prev(s.data.cycleStartDay));
          final isHigh = prevSpent > 0
              ? spent > prevSpent
              : (sal > 0 && spent / sal > 0.80);
          final recent = [
            for (final cItem in f.lastCycles(6))
              f.expensesTotal(cItem).toDouble(),
          ];
          final hasHistory = recent.where((v) => v > 0).length >= 2;
          final sparkPoints = hasHistory ? recent : _dailySpark(f);
          tiles.add(
            DashTile(
              id: id,
              builder: (ctx, w, span) => _statCard(
                ctx,
                'Seus Gastos',
                spent,
                'Neste ciclo',
                hidden,
                background: SparklineBackground(
                  values: sparkPoints,
                  color: isHigh ? ctx.c.negative : ctx.c.positive,
                ),
                onTap: () => ShellScope.of(
                  context,
                )?.goTo(1, filter: const ExtratoFilter()),
              ),
            ),
          );
        case 'caixinhas':
          tiles.add(
            DashTile(
              id: id,
              builder: (ctx, w, span) => _statCard(
                ctx,
                'Caixinhas',
                f.boxesBalanceTotal(),
                'Guardado',
                hidden,
                onTap: () => s.data.boxes.isEmpty
                    ? pushFluid(context, const BoxForm())
                    : ShellScope.of(context)?.goTo(2),
              ),
            ),
          );
        case 'categorias':
          tiles.add(
            DashTile(
              id: id,
              defaultSpan: 2,
              builder: (ctx, w, span) => _categoriesCard(ctx, f, hidden, w),
            ),
          );
        case 'hoje':
          tiles.add(
            DashTile(
              id: id,
              builder: (ctx, w, span) => _todayCard(ctx, f, hidden, w),
            ),
          );
        case 'fds':
          tiles.add(
            DashTile(
              id: id,
              builder: (ctx, w, span) => _weekendCard(ctx, f, hidden, w),
            ),
          );
        case 'projecao':
          tiles.add(
            DashTile(
              id: id,
              defaultSpan: 2,
              builder: (ctx, w, span) => _projectionCard(ctx, f, hidden),
            ),
          );
        case 'assinaturas':
          tiles.add(
            DashTile(
              id: id,
              defaultSpan: 2,
              builder: (ctx, w, span) => _subscriptionsCard(ctx, f, hidden, w),
            ),
          );
        case 'historico':
          tiles.add(
            DashTile(
              id: id,
              defaultSpan: 2,
              builder: (ctx, w, span) => AppCard(
                title: 'Histórico visual',
                onTap: () => push(context, const HistoryScreen()),
                child: HistoryLineChart(
                  f: f,
                  hidden: hidden,
                  height: 148,
                  interactive: false,
                  showAxis: w >= 240,
                  cycles: w < 220 ? 3 : (w < 420 ? 6 : 12),
                ),
              ),
            ),
          );
      }
    }
    return tiles;
  }

  Widget _projectionCard(BuildContext context, Finance f, bool hidden) {
    final c = context.c;
    final cy = f.current;
    final totalDays = cy.days.length.clamp(1, 31);
    final elapsed = (totalDays - f.daysLeftInclToday + 1).clamp(1, totalDays);
    final spentVar = f.variableTotal(cy);
    final avgDaily = spentVar / elapsed;
    final projectedRemainingVar = (avgDaily * (f.daysLeftInclToday - 1))
        .round();
    final projectedEnd = f.freeBalance(cy) - projectedRemainingVar;
    final positive = projectedEnd >= 0;
    return AppCard(
      title: 'Projeção do ciclo',
      onTap: () => push(context, const RhythmScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoneyText(
            projectedEnd,
            hidden: hidden,
            style: T.cardValue,
            color: positive ? c.positive : c.negative,
          ),
          const SizedBox(height: Space.xxs),
          Text(
            positive ? 'Sobra prevista' : 'Falta prevista',
            style: T.small.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _editGrid(BuildContext context, bool noSalary) {
    final s = context.storeRead;
    var order = _allIds(s.data.widgetOrder);
    var hidden = _effectiveHidden(s);

    return showIosSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = ctx.c;
          final available = [
            for (final id in order)
              if (!(noSalary &&
                  (id == 'hoje' || id == 'fds' || id == 'projecao')))
                id,
          ];
          return SheetBody(
            bottom: PillButton('Concluir', onTap: () => Navigator.pop(ctx)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Editar grade',
                        style: T.title.copyWith(color: c.text),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                      onPressed: () {
                        s.resetDashboardLayout();
                        set(() {
                          order = _widgetMeta.keys.toList();
                          hidden = {..._defaultHidden};
                        });
                      },
                      child: Text(
                        'Restaurar',
                        style: T.label.copyWith(
                          color: c.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    RoundIconButton(
                      LucideIcons.x,
                      size: 36,
                      bg: c.cardAlt,
                      label: 'Fechar',
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'Reordene, redimensione (1x ou 2x) ou oculte os cards da Carteira.',
                  style: T.small.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.base),
                ListGroup(
                  bg: c.isDark ? c.bg : c.surfaceLow,
                  gap: 16,
                  children: [
                    for (var idx = 0; idx < available.length; idx++)
                      Builder(
                        builder: (_) {
                          final id = available[idx];
                          final meta = _widgetMeta[id]!;
                          final visible = !hidden.contains(id);
                          final span = s.data.cardSpans[id] ?? meta.$3;
                          return ListRow(
                            leading: SizedBox(
                              width: 32,
                              height: 32,
                              child: Center(
                                child: Icon(
                                  meta.$2,
                                  size: 20,
                                  color: visible ? c.text : c.textTertiary,
                                ),
                              ),
                            ),
                            title: meta.$1,
                            titleColor: visible ? c.text : c.textTertiary,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Pressable(
                                  semanticLabel: 'Largura ${span}x',
                                  onTap: () {
                                    s.setCardSpan(id, span == 1 ? 2 : 1);
                                    set(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Space.sm,
                                      vertical: Space.xs,
                                    ),
                                    decoration: ShapeDecoration(
                                      color: c.primarySoft,
                                      shape: RoundedSuperellipseBorder(
                                        borderRadius: BorderRadius.circular(
                                          Space.radiusSm,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '${span}x',
                                      style: T.smallStrong.copyWith(
                                        color: c.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Space.xs),
                                Pressable(
                                  semanticLabel: 'Mover para cima',
                                  onTap: idx == 0
                                      ? null
                                      : () {
                                          final prevId = available[idx - 1];
                                          final a = order.indexOf(id);
                                          final b = order.indexOf(prevId);
                                          set(() {
                                            order[a] = prevId;
                                            order[b] = id;
                                          });
                                          s.setDashboardLayout(
                                            order: order,
                                            hidden: hidden.toList(),
                                          );
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.all(Space.xs),
                                    child: Icon(
                                      LucideIcons.chevronUp,
                                      size: 18,
                                      color: idx == 0
                                          ? c.textTertiary
                                          : c.textSecondary,
                                    ),
                                  ),
                                ),
                                Pressable(
                                  semanticLabel: 'Mover para baixo',
                                  onTap: idx == available.length - 1
                                      ? null
                                      : () {
                                          final nextId = available[idx + 1];
                                          final a = order.indexOf(id);
                                          final b = order.indexOf(nextId);
                                          set(() {
                                            order[a] = nextId;
                                            order[b] = id;
                                          });
                                          s.setDashboardLayout(
                                            order: order,
                                            hidden: hidden.toList(),
                                          );
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.all(Space.xs),
                                    child: Icon(
                                      LucideIcons.chevronDown,
                                      size: 18,
                                      color: idx == available.length - 1
                                          ? c.textTertiary
                                          : c.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Space.xs),
                                SpringSwitch(
                                  value: visible,
                                  label: meta.$1,
                                  onChanged: (v) {
                                    set(() {
                                      if (v) {
                                        hidden.remove(id);
                                      } else {
                                        hidden.add(id);
                                      }
                                    });
                                    s.setDashboardLayout(
                                      order: order,
                                      hidden: hidden.toList(),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Boa madrugada!';
    if (h < 12) return 'Bom dia!';
    if (h < 18) return 'Boa tarde!';
    return 'Boa noite!';
  }

  Widget _hero(BuildContext context, Finance f, bool hidden) {
    final c = context.c;
    final cy = f.current;
    final (label, value) = switch (_view) {
      HeroView.free => ('Saldo livre do ciclo', f.freeBalance(cy)),
      HeroView.expenses => ('Gastos planejados', f.expensesTotal(cy)),
      HeroView.boxes => ('Guardado nas caixinhas', f.boxesBalanceTotal()),
    };
    return Pressable(
      scale: 0.98,
      semanticLabel: '$label. Toque para alternar.',
      onTap: () => setState(
        () =>
            _view = HeroView.values[(_view.index + 1) % HeroView.values.length],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BlurSwitcher(
                child: Text(
                  label,
                  key: ValueKey(label),
                  style: T.body.copyWith(color: c.text),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronsUpDown,
                size: 14,
                color: c.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          CountingMoney(
            key: ValueKey(_view),
            cents: value,
            builder: (v) => MoneyText(
              v,
              hidden: hidden,
              style: T.hero,
              color: value < 0 ? c.negative : null,
            ),
          ),
        ],
      ),
    );
  }

  List<double> _dailySpark(Finance f) {
    final cy = f.current;
    final items = f.expensesIn(cy);
    final days = cy.days;
    const buckets = 6;
    final perBucket = (days.length / buckets).ceil().clamp(1, 31);
    final totals = List<double>.filled(buckets, 0.0);
    for (final e in items) {
      final diff = e.date.difference(cy.start).inDays;
      final idx = (diff < 0 ? 0 : diff ~/ perBucket).clamp(0, buckets - 1);
      totals[idx] += e.cents.toDouble();
    }
    var running = 0.0;
    return [for (final v in totals) running += v];
  }

  Widget _statCard(
    BuildContext context,
    String title,
    Cents v,
    String caption,
    bool hidden, {
    Widget? background,
    VoidCallback? onTap,
  }) {
    final c = context.c;
    return AppCard(
      expandChild: true,
      title: title,
      background: background,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const SizedBox(height: Space.sm),
          CountingMoney(
            cents: v,
            builder: (x) => MoneyText(x, hidden: hidden, style: T.cardValue),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            caption,
            style: T.small.copyWith(color: c.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _categoriesCard(
    BuildContext context,
    Finance f,
    bool hidden,
    double w,
  ) {
    final c = context.c;
    final data = f.byCategory(f.current);
    final total = data.fold<int>(0, (s, e) => s + e.value);
    final topCount = data.length > 3 ? 3 : data.length;
    final rows = <(String, Cents, Color)>[
      for (var i = 0; i < topCount; i++)
        (data[i].key.label, data[i].value, c.tone(data[i].key.color)),
      if (data.length > topCount)
        (
          'Outros',
          data.skip(topCount).fold<int>(0, (s, e) => s + e.value),
          c.textTertiary.withValues(alpha: 0.45),
        ),
    ];

    Widget ring() => MiniDonutRing(
      size: w < 240 ? 74 : 88,
      stroke: 10,
      values: [for (final r in rows) r.$2.toDouble()],
      colors: [for (final r in rows) r.$3],
      center: data.isEmpty
          ? null
          : Icon(data.first.key.icon, size: 22, color: rows.first.$3),
    );

    Widget legend(int maxRows) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length && i < maxRows; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: rows[i].$3,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rows[i].$1,
                  style: T.small.copyWith(color: c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(rows[i].$2 / total * 100).round()}%',
                style: T.smallStrong.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ],
      ],
    );

    return AppCard(
      title: 'Por categoria',
      onTap: () => push(context, const CategoriesScreen()),
      child: total <= 0
          ? Text(
              'Sem gastos neste ciclo',
              style: T.small.copyWith(color: c.textSecondary),
            )
          : w < 240
          ? Column(
              children: [
                Center(child: ring()),
                const SizedBox(height: Space.md),
                legend(2),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ring(),
                const SizedBox(width: Space.lg),
                Expanded(child: legend(4)),
              ],
            ),
    );
  }

  Widget _todayCard(BuildContext context, Finance f, bool hidden, double w) {
    final c = context.c;
    final v = f.todayAllowance;
    return AppCard(
      expandChild: true,
      title: 'Para hoje',
      onTap: () => push(
        context,
        const RhythmScreen(initialFocus: RhythmFocus.today),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CycleGrid(f: f, width: w, columns: _gridCols(w)),
          const Spacer(),
          const SizedBox(height: Space.base),
          CountingMoney(
            cents: v < 0 ? 0 : v,
            builder: (x) => MoneyText(
              x,
              hidden: hidden,
              style: T.cardValue,
              color: v < 0 ? c.negative : null,
            ),
          ),
          if (v < 0) ...[
            const SizedBox(height: Space.xxs),
            Text(
              'Passou ${fmtMoney(-v, hidden: hidden)}',
              style: T.small.copyWith(color: c.negative),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _weekendCard(BuildContext context, Finance f, bool hidden, double w) {
    final c = context.c;
    final days = f.upcomingWeekend;
    final v = f.weekendAllowance;
    return AppCard(
      expandChild: true,
      title: 'Fim de semana',
      onTap: () => push(
        context,
        const RhythmScreen(initialFocus: RhythmFocus.weekend),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CycleGrid(
            f: f,
            highlight: days.toSet(),
            width: w,
            columns: _gridCols(w),
          ),
          const Spacer(),
          const SizedBox(height: Space.base),
          if (days.isEmpty) ...[
            Text('—', style: T.cardValue.copyWith(color: c.textSecondary)),
            const SizedBox(height: Space.xxs),
            Text(
              'Fora deste ciclo',
              style: T.small.copyWith(color: c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else
            CountingMoney(
              cents: v < 0 ? 0 : v,
              builder: (x) => MoneyText(x, hidden: hidden, style: T.cardValue),
            ),
        ],
      ),
    );
  }

  int _gridCols(double w) => w < 200 ? 8 : (w < 420 ? 16 : 31);

  Widget _subscriptionsCard(
    BuildContext context,
    Finance f,
    bool hidden,
    double w,
  ) {
    final c = context.c;
    final subs = f.subscriptions(f.current);
    final total = subs.fold<int>(0, (s, e) => s + e.cents);

    Widget logoStack() {
      const iconSz = 38.0;
      const step = 28.0;
      final maxLogos = w < 240 ? 3 : 4;
      final shown = subs.take(maxLogos).toList();
      final extra = subs.length - shown.length;
      final count = shown.length + (extra > 0 ? 1 : 0);
      final totalW = iconSz + (count - 1) * step;

      return SizedBox(
        width: totalW,
        height: iconSz + 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: i * step,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: c.card,
                    shape: BoxShape.circle,
                  ),
                  child: BrandLogo(
                    name: shown[i].name,
                    size: iconSz - 4,
                    icon: shown[i].category.icon,
                    color: subscriptionBrandColor(c, shown[i], i),
                  ),
                ),
              ),
            if (extra > 0)
              Positioned(
                left: shown.length * step,
                top: 2,
                child: Container(
                  width: iconSz,
                  height: iconSz,
                  decoration: BoxDecoration(
                    color: c.cardAlt,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.card, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+$extra',
                    style: T.smallStrong.copyWith(color: c.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CountingMoney(
          cents: total,
          builder: (v) => MoneyText(v, hidden: hidden, style: T.cardValue),
        ),
        const SizedBox(height: Space.xxs),
        Text(
          '${subs.length} ${subs.length == 1 ? 'serviço' : 'serviços'} · por mês',
          style: T.small.copyWith(color: c.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return AppCard(
      title: 'Assinaturas',
      onTap: () => push(context, const SubscriptionsScreen()),
      child: subs.isEmpty
          ? Text(
              'Nenhuma assinatura ativa',
              style: T.small.copyWith(color: c.textSecondary),
            )
          : w < 260
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logoStack(),
                const SizedBox(height: Space.md),
                summary,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: summary),
                const SizedBox(width: Space.md),
                logoStack(),
              ],
            ),
    );
  }
}
