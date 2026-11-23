import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
                              'Informe seu salário para acompanhar o saldo livre do ciclo.',
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
                  Builder(
                    builder: (_) {
                      final tiles = _orderedVisibleTiles(
                        context,
                        f,
                        hidden,
                        hasSubs,
                      );
                      if (tiles.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Space.md),
                          child: EmptyState(
                            icon: LucideIcons.wallet,
                            title: 'Seu ciclo está limpo',
                            message:
                                'Registre seu primeiro gasto ou crie uma caixinha para preencher sua carteira.',
                            action: 'Adicionar gasto',
                            onAction: () => openAddExpense(context),
                          ),
                        );
                      }
                      return DashboardGrid(
                        gap: Space.md,
                        spans: s.data.cardSpans,
                        onSpanChanged: s.setCardSpan,
                        tiles: tiles,
                      );
                    },
                  ),
                  const SizedBox(height: Space.sm),
                  Center(
                    child: PillButton(
                      'Editar grade',
                      icon: LucideIcons.slidersHorizontal,
                      kind: BtnKind.ghost,
                      expand: false,
                      height: 44,
                      onTap: () => _editGrid(context),
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
    'assinaturas': ('Assinaturas', LucideIcons.tv, 2),
    'categorias': ('Por categoria', LucideIcons.chartPie, 2),
    'historico': ('Histórico visual', LucideIcons.chartColumn, 2),
  };

  static const _defaultOrder = <String>[
    'gastos',
    'caixinhas',
    'assinaturas',
    'categorias',
    'historico',
  ];

  static const _defaultHidden = <String>{};

  Set<String> _effectiveHidden(Store s) {
    if (s.data.widgetOrder.isEmpty && s.data.hiddenWidgets.isEmpty) {
      return {..._defaultHidden};
    }
    return s.data.hiddenWidgets.toSet();
  }

  int _defaultSpanFor(String id, bool hasOpenBoxes) {
    // Sem caixinhas ativas, Assinaturas nasce como 1x ao lado de Seus Gastos.
    if (id == 'assinaturas' && !hasOpenBoxes) return 1;
    return _widgetMeta[id]?.$3 ?? 1;
  }

  List<String> _allIds(List<String> savedOrder) {
    final ordered = [
      for (final id in savedOrder)
        if (_widgetMeta.containsKey(id)) id,
      for (final id in _defaultOrder)
        if (!savedOrder.contains(id)) id,
    ];
    return ordered;
  }

  List<DashTile> _orderedVisibleTiles(
    BuildContext context,
    Finance f,
    bool hidden,
    bool hasSubs,
  ) {
    final s = context.store;
    final cy = f.current;
    final hiddenSet = _effectiveHidden(s);
    final order = _allIds(s.data.widgetOrder);
    final tiles = <DashTile>[];
    final hasExpenses = f.expensesTotal(cy) > 0;
    final hasOpenBoxes = f.openBoxes.isNotEmpty;
    final hasCategories = f.byCategory(cy).any((entry) => entry.value > 0);
    final hasHistory = f
        .lastCycles(12)
        .any((cycle) => f.expensesTotal(cycle) > 0);

    for (final id in order) {
      if (hiddenSet.contains(id)) continue;
      if (id == 'gastos' && !hasExpenses) continue;
      if (id == 'caixinhas' && !hasOpenBoxes) continue;
      if (id == 'categorias' && !hasCategories) continue;
      if (id == 'assinaturas' && !hasSubs) continue;
      if (id == 'historico' && !hasHistory) continue;

      final defSpan = _defaultSpanFor(id, hasOpenBoxes);

      switch (id) {
        case 'gastos':
          final spent = f.expensesTotal(cy);
          final sal = f.salaryFor(cy);
          final prevSpent = f.expensesTotal(cy.prev(s.data.cycleStartDay));
          final isHigh = prevSpent > 0
              ? spent > prevSpent
              : (sal > 0 && spent / sal > 0.80);
          final sparkPoints = _spendingSpark(f);
          tiles.add(
            DashTile(
              id: id,
              defaultSpan: defSpan,
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
              defaultSpan: defSpan,
              builder: (ctx, w, span) =>
                  _boxesCard(ctx, s, f, hidden, w, span),
            ),
          );
        case 'categorias':
          tiles.add(
            DashTile(
              id: id,
              defaultSpan: defSpan,
              builder: (ctx, w, span) => _categoriesCard(ctx, f, hidden, w),
            ),
          );
        case 'assinaturas':
          tiles.add(
            DashTile(
              id: id,
              defaultSpan: defSpan,
              builder: (ctx, w, span) => _subscriptionsCard(ctx, f, hidden, w),
            ),
          );
        case 'historico':
          tiles.add(
            DashTile(
              id: id,
              defaultSpan: defSpan,
              builder: (ctx, w, span) => AppCard(
                expandChild: true,
                title: 'Histórico visual',
                onTap: () => push(context, const HistoryScreen()),
                child: Center(
                  child: HistoryLineChart(
                    f: f,
                    hidden: hidden,
                    height: w < 220 ? 96 : 148,
                    interactive: false,
                    showAxis: w >= 240,
                    cycles: w < 220 ? 3 : (w < 420 ? 6 : 12),
                  ),
                ),
              ),
            ),
          );
      }
    }
    return tiles;
  }

  Widget _boxesCard(
    BuildContext context,
    Store s,
    Finance f,
    bool hidden,
    double w,
    int span,
  ) {
    final c = context.c;
    final open = f.openBoxes;
    final total = f.boxesBalanceTotal();
    final expanded = span >= 2 && w >= 240;
    final boxSegments = [
      for (final b in open)
        if (f.boxBalance(b) > 0)
          CapsuleSegment(
            value: f.boxBalance(b).toDouble(),
            color: c.tone(b.colorValue),
          ),
    ];

    return AppCard(
      expandChild: true,
      title: 'Caixinhas',
      onTap: () => s.data.boxes.isEmpty
          ? pushFluid(context, const BoxForm())
          : ShellScope.of(context)?.goTo(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          if (expanded && boxSegments.isNotEmpty) ...[
            SegmentedCapsuleBar(
              height: 16,
              gap: 3,
              segments: boxSegments,
            ),
            const SizedBox(height: Space.md),
          ] else
            const SizedBox(height: Space.sm),
          CountingMoney(
            cents: total,
            builder: (x) => MoneyText(x, hidden: hidden, style: T.cardValue),
          ),
          const SizedBox(height: Space.xxs),
          Text(
            expanded
                ? '${open.length} ${open.length == 1 ? 'caixinha ativa' : 'caixinhas ativas'} · Guardado'
                : 'Guardado',
            style: T.small.copyWith(color: c.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _editGrid(BuildContext context) {
    final s = context.storeRead;
    final f = s.f;
    var order = _allIds(s.data.widgetOrder);
    var hidden = _effectiveHidden(s);

    return showIosSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = ctx.c;
          final cy = f.current;
          final hasOpenBoxes = f.openBoxes.isNotEmpty;
          final hasExpenses = f.expensesTotal(cy) > 0;
          final hasCategories = f.byCategory(cy).any((e) => e.value > 0);
          final hasSubs = f.subscriptions(cy).isNotEmpty;
          final hasHistory = f
              .lastCycles(12)
              .any((cycle) => f.expensesTotal(cycle) > 0);
          final wellBg = c.isDark ? c.bg : c.surfaceLow;
          final available = order;

          bool hasDataFor(String id) => switch (id) {
            'gastos' => hasExpenses,
            'caixinhas' => hasOpenBoxes,
            'categorias' => hasCategories,
            'assinaturas' => hasSubs,
            'historico' => hasHistory,
            _ => true,
          };

          int spanOf(String id) =>
              (s.data.cardSpans[id] ?? _defaultSpanFor(id, hasOpenBoxes))
                  .clamp(1, 2);

          // Monta as linhas da miniatura exatamente como o DashboardGrid faz
          final activeIds = [
            for (final id in available)
              if (!hidden.contains(id) && hasDataFor(id)) id,
          ];
          final previewRows = <List<String>>[];
          var curRow = <String>[];
          var curUsed = 0;
          for (final id in activeIds) {
            final sp = spanOf(id);
            if (curRow.isNotEmpty && curUsed + sp > 2) {
              previewRows.add(curRow);
              curRow = [];
              curUsed = 0;
            }
            curRow.add(id);
            curUsed += sp;
          }
          if (curRow.isNotEmpty) previewRows.add(curRow);

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
                          order = _defaultOrder.toList();
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
                  'Toque num bloco da prévia para alternar entre 1x e 2x, ou ajuste a ordem abaixo.',
                  style: T.small.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.base),

                // ── Prévia visual interativa da grade (2 colunas)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: ShapeDecoration(
                    color: wellBg,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: previewRows.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Nenhum card ativo com dados neste ciclo.',
                            textAlign: TextAlign.center,
                            style: T.small.copyWith(color: c.textTertiary),
                          ),
                        )
                      : Column(
                          children: [
                            for (var r = 0; r < previewRows.length; r++) ...[
                              if (r > 0) const SizedBox(height: 8),
                              () {
                                final row = previewRows[r];
                                final used = row.fold<int>(
                                  0,
                                  (sum, id) => sum + spanOf(id),
                                );
                                final leftover = (2 - used).clamp(0, 2);
                                return Row(
                                  children: [
                                    for (var i = 0; i < row.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 8),
                                      () {
                                        final id = row[i];
                                        final meta = _widgetMeta[id]!;
                                        final sp = spanOf(id);
                                        final (tBg, tFg) = softActionTone(
                                          c.palette.primary[500],
                                          isDark: c.isDark,
                                        );
                                        return Expanded(
                                          flex: sp,
                                          child: Pressable(
                                            scale: 0.97,
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              s.setCardSpan(
                                                id,
                                                sp == 1 ? 2 : 1,
                                              );
                                              set(() {});
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              height: 52,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              decoration: ShapeDecoration(
                                                color: c.card,
                                                shape:
                                                    RoundedSuperellipseBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                    ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    meta.$2,
                                                    size: 16,
                                                    color: c.primary,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      meta.$1,
                                                      style: T.smallStrong
                                                          .copyWith(
                                                            color: c.text,
                                                          ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: ShapeDecoration(
                                                      color: tBg,
                                                      shape:
                                                          const StadiumBorder(),
                                                    ),
                                                    child: Text(
                                                      '${sp}x',
                                                      style: T.tiny.copyWith(
                                                        color: tFg,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }(),
                                    ],
                                    if (leftover > 0) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: leftover,
                                        child: Container(
                                          height: 52,
                                          decoration: ShapeDecoration(
                                            color: c.card.withValues(
                                              alpha: 0.25,
                                            ),
                                            shape: RoundedSuperellipseBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              }(),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: Space.base),

                ListGroup(
                  bg: wellBg,
                  gap: 16,
                  children: [
                    for (var idx = 0; idx < available.length; idx++)
                      Builder(
                        builder: (_) {
                          final id = available[idx];
                          final meta = _widgetMeta[id]!;
                          final isBoxDisabled =
                              id == 'caixinhas' && !hasOpenBoxes;
                          final visible =
                              !isBoxDisabled && !hidden.contains(id);
                          final span = spanOf(id);
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
                            subtitle: isBoxDisabled
                                ? 'Desativado · sem caixinha ativa'
                                : (!hasDataFor(id) ? 'Sem dados no ciclo' : null),
                            titleColor: visible ? c.text : c.textTertiary,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isBoxDisabled)
                                  Pressable(
                                    semanticLabel: 'Largura ${span}x',
                                    onTap: () {
                                      HapticFeedback.selectionClick();
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
                                if (isBoxDisabled)
                                  Tag(
                                    'Inativo',
                                    bg: c.cardAlt,
                                    fg: c.textTertiary,
                                  )
                                else
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

  /// Pontos de gastos por faixa do ciclo (não cumulativo, para subir e descer
  /// naturalmente como um gráfico real de movimentação).
  List<double> _spendingSpark(Finance f) {
    final cy = f.current;
    final items = f.expensesIn(cy);
    final days = cy.days;
    const buckets = 8;
    final perBucket = (days.length / buckets).ceil().clamp(1, 31);
    final totals = List<double>.filled(buckets, 0.0);
    for (final e in items) {
      final diff = e.date.difference(cy.start).inDays;
      final idx = (diff < 0 ? 0 : diff ~/ perBucket).clamp(0, buckets - 1);
      totals[idx] += e.cents.toDouble();
    }
    if (totals.where((v) => v > 0).length >= 3) return totals;
    // Fallback para histórico dos últimos ciclos se o ciclo atual ainda tem poucos pontos.
    final hist = [
      for (final cItem in f.lastCycles(6)) f.expensesTotal(cItem).toDouble(),
    ];
    return hist.where((v) => v > 0).length >= 2 ? hist : totals;
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
      expandChild: true,
      title: 'Por categoria',
      onTap: () => push(context, const CategoriesScreen()),
      child: total <= 0
          ? Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Sem gastos neste ciclo',
                style: T.small.copyWith(color: c.textSecondary),
              ),
            )
          : w < 240
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Center(child: ring()),
                const SizedBox(height: Space.sm),
                legend(2),
              ],
            )
          : Center(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ring(),
                  const SizedBox(width: Space.lg),
                  Expanded(child: legend(4)),
                ],
              ),
            ),
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
    final compact = w < 260;

    Widget logoStack() {
      final iconSz = compact ? 28.0 : 38.0;
      final step = compact ? 20.0 : 28.0;
      final maxLogos = compact ? 3 : 4;
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
                child: BrandLogo(
                  name: shown[i].name,
                  size: iconSz,
                  icon: shown[i].category.icon,
                  color: subscriptionBrandColor(c, shown[i], i),
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
                    style: (compact ? T.tiny : T.smallStrong).copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
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
      expandChild: true,
      title: 'Assinaturas',
      onTap: () => push(context, const SubscriptionsScreen()),
      child: subs.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Nenhuma assinatura ativa',
                style: T.small.copyWith(color: c.textSecondary),
              ),
            )
          : compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                logoStack(),
                const SizedBox(height: Space.xs),
                summary,
              ],
            )
          : Center(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: Space.md),
                  logoStack(),
                ],
              ),
            ),
    );
  }
}
