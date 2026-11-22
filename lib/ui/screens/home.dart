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
                          style: T.headline.copyWith(
                            color: c.text,
                            fontSize: 20,
                          ),
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
                    bg: c.card.withValues(alpha: 0.78),
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
                Space.lg,
                sidePadding(context, maxWidth: 1200),
                navClearance(context),
              ),
              sliver: SliverList.list(
                children: [
                  // ── Valor principal (toque alterna a visão)
                  _hero(context, f, hidden),
                  const SizedBox(height: Space.lg),

                  // ── Cartões (oculto se o usuário não tiver nenhum)
                  if (hasCards) ...[
                    CardsStrip(hidden: hidden),
                    const SizedBox(height: Space.base),
                  ],

                  // ── Ações rápidas: círculo com ícone e nome embaixo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAction(icon: LucideIcons.plus, label: 'Gasto', primary: true, onTap: () => openAddExpense(context)),
                      CircleAction(icon: LucideIcons.piggyBank, label: 'Caixinha', onTap: () => pushFluid(context, const BoxForm())),
                      CircleAction(icon: LucideIcons.creditCard, label: 'Cartão', onTap: () => editCard(context)),
                      CircleAction(icon: LucideIcons.ellipsis, label: 'Mais', onTap: () => _moreActions(context)),
                    ],
                  ),
                  const SizedBox(height: Space.lg),

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
    'gastos': ('Seus Gastos', LucideIcons.receipt, 1),
    'caixinhas': ('Caixinhas', LucideIcons.piggyBank, 1),
    'categorias': ('Gastos por categoria', LucideIcons.chartPie, 2),
    'hoje': ('Para hoje', LucideIcons.calendarCheck, 1),
    'fds': ('Fim de semana', LucideIcons.sun, 1),
    'projecao': ('Projeção do ciclo', LucideIcons.trendingUp, 2),
    'sequencia': ('Sequência', LucideIcons.zap, 2),
    'assinaturas': ('Assinaturas', LucideIcons.tv, 2),
    'historico': ('Histórico visual', LucideIcons.chartColumn, 2),
  };

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
    final hiddenSet = s.data.hiddenWidgets.toSet();
    final order = _allIds(s.data.widgetOrder);
    final tiles = <DashTile>[];

    for (final id in order) {
      if (hiddenSet.contains(id)) continue;
      if (noSalary &&
          (id == 'hoje' ||
              id == 'fds' ||
              id == 'sequencia' ||
              id == 'projecao'))
        continue;
      if (id == 'categorias' &&
          f.byCategory(cy).isEmpty &&
          !s.data.widgetOrder.contains('categorias'))
        continue;
      if (id == 'assinaturas' &&
          !hasSubs &&
          !s.data.widgetOrder.contains('assinaturas'))
        continue;

      switch (id) {
        case 'gastos':
          final spent = f.expensesTotal(cy);
          final sal = f.salaryFor(cy);
          final ratio = sal > 0 ? (spent / sal).clamp(0.0, 1.0) : 0.0;
          tiles.add(
            DashTile(
              id: id,
              builder: (ctx, w, span) => _statCard(
                ctx,
                'Seus Gastos',
                spent,
                sal > 0
                    ? '${(ratio * 100).round()}% do salário'
                    : 'Neste ciclo',
                hidden,
                progress: sal > 0 ? ratio : null,
                progressColor: ratio > 0.85 ? ctx.c.negative : ctx.c.primary,
                onTap: () => ShellScope.of(
                  context,
                )?.goTo(1, filter: const ExtratoFilter()),
              ),
            ),
          );
        case 'caixinhas':
          final boxes = f.openBoxes;
          final monthly = boxes.fold<int>(
            0,
            (t, b) => t + f.contributionFor(b, cy),
          );
          tiles.add(
            DashTile(
              id: id,
              builder: (ctx, w, span) => _statCard(
                ctx,
                'Caixinhas',
                f.boxesBalanceTotal(),
                boxes.isEmpty
                    ? 'Guardados agora'
                    : '+${fmtMoney(monthly, hidden: hidden)}/ciclo',
                hidden,
                badge: boxes.isEmpty
                    ? null
                    : '${boxes.length} ${boxes.length == 1 ? 'ativa' : 'ativas'}',
                onTap: () => ShellScope.of(context)?.goTo(2),
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
        case 'sequencia':
          tiles.add(
            DashTile(
              id: id,
              defaultSpan: 2,
              builder: (ctx, w, span) => _streakCard(ctx, f, w),
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
                child: HistoryBars(
                  f: f,
                  hidden: hidden,
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoneyText(
                  projectedEnd,
                  hidden: hidden,
                  style: T.cardValue,
                  color: positive ? c.positive : c.negative,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  positive
                      ? 'Estimativa de sobra no ritmo atual'
                      : 'No ritmo atual pode faltar no fim do ciclo',
                  style: T.small.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: positive ? c.positiveSoft : c.negativeSoft,
              borderRadius: BorderRadius.circular(Space.radiusMd),
            ),
            child: Icon(
              positive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              color: positive ? c.positive : c.negative,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGrid(BuildContext context, bool noSalary) {
    final s = context.storeRead;
    var order = _allIds(s.data.widgetOrder);
    var hidden = s.data.hiddenWidgets.toSet();

    return showSheet(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = ctx.c;
          final available = [
            for (final id in order)
              if (!(noSalary &&
                  (id == 'hoje' ||
                      id == 'fds' ||
                      id == 'sequencia' ||
                      id == 'projecao')))
                id,
          ];
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.md,
              Space.lg,
              Space.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Editar grade',
                        style: T.headline.copyWith(color: c.text),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        s.resetDashboardLayout();
                        set(() {
                          order = _widgetMeta.keys.toList();
                          hidden = {};
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
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'Reordene, redimensione (1x ou 2x) ou oculte os cards da Carteira.',
                  style: T.small.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.base),
                for (var idx = 0; idx < available.length; idx++) ...[
                  Builder(
                    builder: (_) {
                      final id = available[idx];
                      final meta = _widgetMeta[id]!;
                      final visible = !hidden.contains(id);
                      final span = s.data.cardSpans[id] ?? meta.$3;
                      return Container(
                        margin: const EdgeInsets.only(bottom: Space.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.md,
                          vertical: Space.sm,
                        ),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(
                            Space.radiusField,
                          ),
                          border: Border.all(
                            color: c.border.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              meta.$2,
                              size: 18,
                              color: visible ? c.accent : c.textTertiary,
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Text(
                                meta.$1,
                                style: T.label.copyWith(
                                  color: visible ? c.text : c.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                                decoration: BoxDecoration(
                                  color: c.primarySoft,
                                  borderRadius: BorderRadius.circular(
                                    Space.radiusSm,
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
                const SizedBox(height: Space.md),
                PillButton('Concluir', onTap: () => Navigator.pop(ctx)),
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
              style: T.display.copyWith(fontSize: 36),
              color: value < 0 ? c.negative : null,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            '${cy.label()} · ${cy.start.day}/${cy.start.month} a ${cy.end.subtract(const Duration(days: 1)).day}/${cy.end.subtract(const Duration(days: 1)).month}',
            style: T.label.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String title,
    Cents v,
    String caption,
    bool hidden, {
    double? progress,
    Color? progressColor,
    String? badge,
    VoidCallback? onTap,
  }) {
    final c = context.c;
    return AppCard(
      title: title,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress != null) ...[
            const SizedBox(height: Space.xs),
            SpringBar(
              fraction: progress,
              color: progressColor ?? c.primary,
              track: c.cardAlt,
              height: 6,
            ),
          ] else if (badge != null) ...[
            const SizedBox(height: Space.xs),
            Tag(badge, bg: c.primarySoft, fg: c.accent),
          ],
          const SizedBox(height: Space.lg),
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
    final shades = categoryShades(c);
    final rows = <(String, Cents, Color)>[];
    for (var k = 0; k < data.length && k < 3; k++) {
      rows.add((data[k].key.label, data[k].value, shades[k]));
    }
    if (data.length > 3) {
      rows.add((
        'Outros',
        data.skip(3).fold(0, (s, e) => s + e.value),
        c.emptyCell,
      ));
    }
    return AppCard(
      title: 'Gastos por categoria',
      onTap: () => push(context, const CategoriesScreen()),
      child: total <= 0
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Seus gastos aparecem aqui, separados por categoria.',
                style: T.label.copyWith(color: c.textSecondary),
              ),
            )
          : Flex(
              direction: w < 280 ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CategoryWaffle(
                  data: data,
                  width: w < 280 ? w : (w * 0.36).clamp(100.0, 200.0),
                ),
                const SizedBox(width: 16, height: 14),
                Flexible(
                  fit: w < 280 ? FlexFit.loose : FlexFit.tight,
                  child: Column(
                    children: [
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: r.$3,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.$1,
                                      style: T.small.copyWith(color: c.text),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      fmtMoney(r.$2, hidden: hidden),
                                      style: T.tiny.copyWith(
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(r.$2 / total * 100).round()}%',
                                style: T.bodyStrong.copyWith(color: c.text),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _todayCard(BuildContext context, Finance f, bool hidden, double w) {
    final c = context.c;
    final v = f.todayAllowance;
    return AppCard(
      title: 'Para hoje',
      onTap: () => push(context, const RhythmScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CycleGrid(f: f, width: w, columns: _gridCols(w)),
          const SizedBox(height: Space.lg),
          CountingMoney(
            cents: v < 0 ? 0 : v,
            builder: (x) => MoneyText(x, hidden: hidden, style: T.cardValue),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            v < 0
                ? 'Passou ${fmtMoney(-v, hidden: hidden)} hoje'
                : 'Pode gastar hoje',
            style: T.small.copyWith(
              color: v < 0 ? c.negative : c.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _weekendCard(BuildContext context, Finance f, bool hidden, double w) {
    final c = context.c;
    final days = f.upcomingWeekend;
    final v = f.weekendAllowance;
    return AppCard(
      title: 'Fim de semana',
      onTap: () => push(context, const RhythmScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CycleGrid(
            f: f,
            highlight: days.toSet(),
            width: w,
            columns: _gridCols(w),
          ),
          const SizedBox(height: Space.lg),
          if (days.isEmpty) ...[
            Text('—', style: T.cardValue.copyWith(color: c.textSecondary)),
            const SizedBox(height: Space.xxs),
            Text(
              'Sem fim de semana neste ciclo',
              style: T.small.copyWith(color: c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else ...[
            CountingMoney(
              cents: v < 0 ? 0 : v,
              builder: (x) => MoneyText(x, hidden: hidden, style: T.cardValue),
            ),
            const SizedBox(height: Space.xxs),
            Text(
              'No fim de semana',
              style: T.small.copyWith(color: c.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  int _gridCols(double w) => w < 200 ? 8 : (w < 420 ? 16 : 31);

  Widget _streakCard(BuildContext context, Finance f, double w) {
    final c = context.c;
    final n = f.streak;
    final hidden = context.store.data.hideValues;
    final msg =
        'Meta diária: ${fmtMoney(f.idealDaily(f.current), hidden: hidden)}';
    return AppCard(
      onTap: () => push(context, const RhythmScreen()),
      titleWidget: Row(
        children: [
          Icon(LucideIcons.zap, color: c.accentWarm, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == 1 ? '1 dia de sequência' : '$n dias de sequência',
                  style: T.headline.copyWith(
                    color: c.text,
                    fontSize: w < 240 ? 16 : 20,
                  ),
                ),
                if (w >= 240)
                  Text(msg, style: T.small.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      child: WeekStreak(f: f, width: w),
    );
  }

  Widget _subscriptionsCard(
    BuildContext context,
    Finance f,
    bool hidden,
    double w,
  ) {
    final c = context.c;
    final subs = f.subscriptions(f.current);
    final total = subs.fold<int>(0, (s, e) => s + e.cents);
    return AppCard(
      title: 'Assinaturas',
      onTap: () => push(context, const SubscriptionsScreen()),
      child: subs.isEmpty
          ? Text(
              'Cadastre gastos na categoria Assinaturas (Netflix, Spotify…) para acompanhar aqui.',
              style: T.label.copyWith(color: c.textSecondary),
            )
          : w < 280
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoneyText(total, hidden: hidden, style: T.cardValue),
                Text(
                  'Por mês em ${subs.length} ${subs.length == 1 ? 'serviço' : 'serviços'}',
                  style: T.small.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 8),
                SubscriptionBubbles(subs: subs, hidden: hidden, width: w),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: w * 0.45,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MoneyText(total, hidden: hidden, style: T.cardValue),
                      Text(
                        'Por mês em ${subs.length} ${subs.length == 1 ? 'serviço' : 'serviços'}',
                        style: T.small.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                SubscriptionBubbles(
                  subs: subs,
                  hidden: hidden,
                  width: w * 0.55,
                ),
              ],
            ),
    );
  }

  Future<void> _moreActions(BuildContext context) async {
    final a = await actionSheet<String>(
      context,
      actions: const [
        SheetAction('Atualizar salário', 'salary', icon: LucideIcons.banknote),
        SheetAction('Nova conta ou cartão', 'card', icon: LucideIcons.landmark),
        SheetAction('Ritmo do ciclo', 'rhythm', icon: LucideIcons.calendarDays),
        SheetAction('Histórico', 'history', icon: LucideIcons.chartColumn),
      ],
    );
    if (!context.mounted) return;
    switch (a) {
      case 'salary':
        editSalary(context);
      case 'card':
        editCard(context);
      case 'rhythm':
        push(context, const RhythmScreen());
      case 'history':
        push(context, const HistoryScreen());
    }
  }
}
