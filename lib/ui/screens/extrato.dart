import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/perf.dart';
import '../../core/theme.dart';
import '../../data/brands.dart';
import '../../data/finance.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/charts.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'add_expense.dart';
import 'expense_sheet.dart';
import 'shell.dart';

class ExtratoFilter {
  final String? categoryId;
  final String? cardId;
  const ExtratoFilter({this.categoryId, this.cardId});
}

/// Extrato: aba Todos mantém recorrentes e únicos juntos; Recorrentes e Únicos
/// separam conforme a aba superior. Tocar na busca abre página dedicada.
class ExtratoScreen extends StatefulWidget {
  final ValueNotifier<ExtratoFilter?>? filter;
  final ExtratoFilter? initialFilter;
  final bool standalone;
  const ExtratoScreen({
    super.key,
    this.filter,
    this.initialFilter,
    this.standalone = false,
  });
  @override
  State<ExtratoScreen> createState() => _ExtratoScreenState();
}

class _ExtratoScreenState extends State<ExtratoScreen> {
  int _offset = 0; // 0 = ciclo atual, -1 = anterior…
  String? _cat;
  String? _card;
  int _kind = 0; // 0 todos, 1 recorrentes, 2 únicos

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFilter ?? widget.filter?.value;
    if (initial != null) {
      _cat = initial.categoryId;
      _card = initial.cardId;
      if (widget.filter != null) widget.filter!.value = null;
    }
    widget.filter?.addListener(_applyExternal);
  }

  void _applyExternal() {
    final f = widget.filter?.value;
    if (f == null) return;
    setState(() {
      _offset = 0;
      _cat = f.categoryId;
      _card = f.cardId;
    });
    widget.filter!.value = null;
  }

  @override
  void dispose() {
    widget.filter?.removeListener(_applyExternal);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final cy = f.fromKey(f.current.key + _offset);
    final hidden = s.data.hideValues;
    final allInCycle = f.expensesIn(cy);
    final activeCard = _card == null ? null : s.card(_card);
    final effectiveCardId = activeCard?.id;
    final activeCat = _cat == null ? null : categoryById(_cat!);
    var items = allInCycle;
    if (_cat != null) items = items.where((e) => e.categoryId == _cat).toList();
    if (effectiveCardId != null) {
      items = items.where((e) => e.cardId == effectiveCardId).toList();
    }

    if (_kind == 1) items = items.where((e) => e.isRecurring).toList();
    if (_kind == 2) items = items.where((e) => !e.isRecurring).toList();

    // Em "Todos", recorrentes e únicos ficam juntos numa lista unificada.
    final unified = [...items]
      ..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.cents.compareTo(a.cents);
      });
    final recurringOnly = items.where((e) => e.isRecurring).toList()
      ..sort((a, b) => b.cents.compareTo(a.cents));
    final onceOnly = items.where((e) => !e.isRecurring).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final byDay = <DateTime, List<Expense>>{};
    for (final e in onceOnly) {
      byDay.putIfAbsent(dateOnly(e.date), () => []).add(e);
    }

    final total = items.fold<int>(0, (t, e) => t + e.cents);
    final salary = f.salaryFor(cy);
    final pad = sidePadding(context);
    final usedCats = allInCycle.map((e) => e.categoryId).toSet();
    final activeFilterCount =
        (_cat != null ? 1 : 0) + (effectiveCardId != null ? 1 : 0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final fabBottom = (bottomInset > 0 ? bottomInset : Space.base) + Space.sm;

    final body = Stack(
      children: [
        GlowScrollStack(
          height: 440,
          child: CollapsingTitleScope(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              PinnedCupertinoBar(
                height: 60,
                builder: (ctx, progress) => Row(
                  children: [
                    if (widget.standalone) ...[
                      const BackChevron(),
                      Expanded(child: BarTitle('Extrato', progress: progress)),
                    ] else
                      Expanded(
                        child: Text(
                          'Extrato',
                          style: T.pageTitle.copyWith(color: c.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(width: Space.sm),
                    _CycleBarPill(
                      label: cy.label(),
                      onPick: () => _openCyclePicker(context, f),
                    ),
                  ],
                ),
              ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, 0),
          sliver: SliverList.list(
            children: [
              if (widget.standalone) ...[
                LargeTitle('Extrato', style: T.pageTitle),
                const SizedBox(height: Space.base),
              ],
              Segmented<int>(
                    value: _kind,
                    options: const {0: 'Todos', 1: 'Recorrentes', 2: 'Únicos'},
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                  const SizedBox(height: Space.lg),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CountingMoney(
                        cents: total,
                        builder: (v) => MoneyText(
                          v,
                          hidden: hidden,
                          style: T.displayLg,
                        ),
                      ),
                      if (salary > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'de ${fmtMoney(salary, hidden: hidden)}',
                          style: T.small.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    HistoryLineChart(
                      f: f,
                      cycles: 3,
                      anchorCycle: cy,
                      height: 136,
                      hidden: hidden,
                      valueFor: (cItem) {
                        var list = f.expensesIn(cItem);
                        if (_cat != null) {
                          list = list.where((e) => e.categoryId == _cat).toList();
                        }
                        if (effectiveCardId != null) {
                          list = list
                              .where((e) => e.cardId == effectiveCardId)
                              .toList();
                        }
                        if (_kind == 1) {
                          list = list.where((e) => e.isRecurring).toList();
                        }
                        if (_kind == 2) {
                          list = list.where((e) => !e.isRecurring).toList();
                        }
                        return list.fold<int>(0, (t, e) => t + e.cents);
                      },
                    ),
                  ],
                  const SizedBox(height: Space.lg),
                  // Barra de busca em pílula (com transição Hero) + botão de filtros ao lado
                  Row(
                    children: [
                      Expanded(
                        child: Pressable(
                          semanticLabel: 'Buscar gasto ou categoria',
                          scale: 0.985,
                          onTap: () => _openSearch(context, cy),
                          child: Hero(
                            tag: _searchHeroTag,
                            flightShuttleBuilder: _searchShuttle,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.base,
                              ),
                              decoration: ShapeDecoration(
                                color: c.card,
                                shape: const StadiumBorder(),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.search,
                                    size: 18,
                                    color: c.textSecondary,
                                  ),
                                  const SizedBox(width: Space.sm),
                                  Expanded(
                                    child: Text(
                                      'Buscar gasto ou categoria',
                                      style: T.body.copyWith(
                                        color: c.textTertiary,
                                        decoration: TextDecoration.none,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      _FilterButton(
                        activeCount: activeFilterCount,
                        onTap: () => _showExtratoFilterSheet(
                          context,
                          usedCats: usedCats,
                          selectedCard: _card,
                          selectedCat: _cat,
                          onApply: (card, cat) => setState(() {
                            _card = card;
                            _cat = cat;
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (activeCard != null || activeCat != null) ...[
                    const SizedBox(height: Space.md),
                    _ActiveFiltersRow(
                      card: activeCard,
                      category: activeCat,
                      onClearCard: () => setState(() => _card = null),
                      onClearCategory: () => setState(() => _cat = null),
                      onClearAll: () => setState(() {
                        _cat = null;
                        _card = null;
                      }),
                    ),
                  ],
                ],
              ),
            ),
            if (items.isEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  Space.base,
                  pad,
                  (widget.standalone
                          ? Space.xl + bottomInset
                          : navClearance(context)) +
                      68,
                ),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: EmptyState(
                      icon: LucideIcons.receipt,
                      title: _cat != null || _card != null
                          ? 'Nenhum gasto com esse filtro'
                          : 'Sem gastos neste ciclo',
                      message: _cat != null || _card != null
                          ? 'Remova os filtros para ver todos os lançamentos'
                          : 'Os gastos registrados aparecem aqui',
                      action: _cat != null || _card != null
                          ? 'Limpar filtros'
                          : (_offset == 0 ? 'Adicionar gasto' : null),
                      onAction: _cat != null || _card != null
                          ? () => setState(() {
                              _cat = null;
                              _card = null;
                            })
                          : () => openAddExpense(context),
                    ),
                  ),
                ),
              )
            else if (_kind == 0)
              // Aba "Todos" lazy: constrói só os gastos visíveis na tela.
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  Space.base,
                  pad,
                  (widget.standalone
                          ? Space.xl + bottomInset
                          : navClearance(context)) +
                      68,
                ),
                sliver: SliverListGroup(
                  itemCount: unified.length,
                  itemBuilder: (_, i) =>
                      ExpenseRow(e: unified[i], f: f, hidden: hidden),
                ),
              )
            else if (_kind == 1)
              // Aba "Recorrentes" lazy (sem título redundante acima da lista)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  Space.base,
                  pad,
                  (widget.standalone
                          ? Space.xl + bottomInset
                          : navClearance(context)) +
                      68,
                ),
                sliver: SliverListGroup(
                  itemCount: recurringOnly.length,
                  itemBuilder: (_, i) =>
                      ExpenseRow(e: recurringOnly[i], f: f, hidden: hidden),
                ),
              ) else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  Space.base,
                  pad,
                  (widget.standalone
                          ? Space.xl + bottomInset
                          : navClearance(context)) +
                      68,
                ),
                sliver: SliverList.builder(
                  itemCount: byDay.length,
                  itemBuilder: (_, idx) {
                    final day = byDay.keys.elementAt(idx);
                    final dayItems = byDay[day]!;
                    return ListGroup(
                      title: _dayLabel(day),
                      trailing: Text(
                        fmtMoney(
                          dayItems.fold(0, (t, e) => t + e.cents),
                          hidden: hidden,
                        ),
                        style: T.smallStrong.copyWith(color: c.textSecondary),
                      ),
                      children: [
                        for (final e in dayItems)
                          ExpenseRow(e: e, f: f, hidden: hidden),
                      ],
                    );
                  },
                ),
              ),
          ],
          ),
        ),
        ),
        // Botão flutuante no modo standalone (quando na navbar, o Shell desenha acima do blur)
        if (widget.standalone)
          Positioned(
            right: pad,
            bottom: fabBottom,
            child: Pressable(
              semanticLabel: 'Adicionar gasto',
              scale: 0.92,
              onTap: () => openAddExpense(context),
              child: Builder(
                builder: (_) {
                  final (fabBg, fabFg) = softActionTone(
                    c.palette.primary[500],
                    isDark: c.isDark,
                  );
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: fabBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Palette.neutral950.withValues(
                            alpha: c.isDark ? 0.48 : 0.18,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(LucideIcons.plus, size: 24, color: fabFg),
                  );
                },
              ),
            ),
          ),
      ],
    );

    if (!widget.standalone) return body;
    return SheetScaler(
      child: CupertinoPageScaffold(backgroundColor: c.bg, child: body),
    );
  }

  void _openSearch(BuildContext context, Cycle cy) {
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => ExtratoSearchScreen(
          cycle: cy,
          initialCard: _card,
          initialCat: _cat,
        ),
        transitionsBuilder: (_, anim, _, child) {
          final curve = CurvedAnimation(
            parent: anim,
            curve: easeOutExpo,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCyclePicker(BuildContext context, Finance f) {
    const monthNames = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    final curKey = f.current.key;
    final activeKey = curKey + _offset;
    var viewYear = activeKey ~/ 12;
    final minYear = (curKey ~/ 12) - 4;
    final maxYear = (curKey ~/ 12) + 2;

    return showSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = ctx.c;
          final (selBg, selFg) = softActionTone(
            c.palette.primary[500],
            isDark: c.isDark,
          );
          return SheetBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Escolher ciclo',
                        style: T.title.copyWith(color: c.text),
                      ),
                    ),
                    if (_offset != 0)
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.sm,
                        ),
                        onPressed: () {
                          setState(() => _offset = 0);
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Ciclo atual',
                          style: T.labelStrong.copyWith(color: c.primary),
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
                const SizedBox(height: Space.md),
                // Seletor de ano compacto
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                  decoration: ShapeDecoration(
                    color: c.isDark ? c.cardAlt : c.surfaceLow,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    children: [
                      RoundIconButton(
                        LucideIcons.chevronLeft,
                        size: 34,
                        bg: const Color(0x00000000),
                        fg: viewYear > minYear ? c.text : c.textTertiary,
                        label: 'Ano anterior',
                        onTap: viewYear > minYear
                            ? () => set(() => viewYear--)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          '$viewYear',
                          textAlign: TextAlign.center,
                          style: T.bodyStrong.copyWith(color: c.text),
                        ),
                      ),
                      RoundIconButton(
                        LucideIcons.chevronRight,
                        size: 34,
                        bg: const Color(0x00000000),
                        fg: viewYear < maxYear ? c.text : c.textTertiary,
                        label: 'Próximo ano',
                        onTap: viewYear < maxYear
                            ? () => set(() => viewYear++)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                // Grade 3x4 dos 12 meses do ano
                LayoutBuilder(
                  builder: (_, box) {
                    const gap = 8.0;
                    final tileW = (box.maxWidth - gap * 2) / 3;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var m = 0; m < 12; m++)
                          () {
                            final key = viewYear * 12 + m;
                            final off = key - curKey;
                            final selected = key == activeKey;
                            final isCurrent = key == curKey;
                            return Pressable(
                              scale: 0.96,
                              onTap: () {
                                setState(() => _offset = off);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                width: tileW,
                                height: 54,
                                decoration: ShapeDecoration(
                                  color: selected
                                      ? selBg
                                      : (c.isDark ? c.cardAlt : c.surfaceLow),
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: isCurrent && !selected
                                        ? BorderSide(
                                            color: c.primary.withValues(
                                              alpha: 0.55,
                                            ),
                                            width: 1.5,
                                          )
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      monthNames[m],
                                      style:
                                          (selected
                                                  ? T.bodyStrong
                                                  : T.bodyMedium)
                                              .copyWith(
                                                color: selected
                                                    ? selFg
                                                    : (isCurrent
                                                          ? c.primary
                                                          : c.text),
                                              ),
                                    ),
                                    if (isCurrent) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Atual',
                                        style: T.tiny.copyWith(
                                          color: selected ? selFg : c.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }(),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final today = dateOnly(DateTime.now());
    if (sameDay(d, today)) return 'Hoje';
    if (sameDay(d, today.subtract(const Duration(days: 1)))) return 'Ontem';
    final raw = DateFormat("EEEE, d 'de' MMM", 'pt_BR').format(d);
    return raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
  }
}

const _searchHeroTag = 'extrato-search-bar';

Widget _searchShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final c = flightContext.c;
  return Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: Space.base),
    decoration: ShapeDecoration(color: c.card, shape: const StadiumBorder()),
    child: Row(
      children: [
        Icon(LucideIcons.search, size: 18, color: c.textSecondary),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            'Buscar gasto ou categoria',
            style: T.body.copyWith(
              color: c.textTertiary,
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Seletor compacto de ciclo na top bar do Extrato: vidro fosco com nome do
/// mês e seta para baixo para abrir o seletor rápido de ciclos.
class _CycleBarPill extends StatelessWidget {
  final String label;
  final VoidCallback onPick;
  const _CycleBarPill({
    required this.label,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final perf = context.perf;
    final sigma = 24.0 * perf.glassSigmaFactor;
    final glassBg = c.isDark
        ? (perf.allowBlur
              ? const Color(0xFF16161A).withValues(alpha: 0.56)
              : c.card)
        : (perf.allowBlur
              ? const Color(0xFFFFFFFF).withValues(alpha: 0.62)
              : Palette.neutral0);
    final pill = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: ShapeDecoration(
        color: glassBg,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: c.isDark
                ? Palette.neutral0.withValues(alpha: 0.12)
                : Palette.neutral950.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlurSwitcher(
            alignment: Alignment.center,
            child: Text(
              label,
              key: ValueKey(label),
              style: T.labelStrong.copyWith(color: c.text),
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            LucideIcons.chevronDown,
            size: 15,
            color: c.textSecondary,
          ),
        ],
      ),
    );
    return Pressable(
      semanticLabel: 'Escolher ciclo',
      scale: 0.95,
      onTap: onPick,
      child: perf.allowBlur && sigma >= 1.0
          ? ClipRSuperellipse(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: pill,
              ),
            )
          : pill,
    );
  }
}

/// Botão circular de filtros (compartilhado entre Extrato e Busca).
class _FilterButton extends StatelessWidget {
  final int activeCount;
  final VoidCallback onTap;
  const _FilterButton({required this.activeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      semanticLabel: 'Filtrar gastos',
      scale: 0.94,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: activeCount > 0 ? c.primary : c.card,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.slidersHorizontal,
              size: 20,
              color: activeCount > 0 ? c.onPrimary : c.textSecondary,
            ),
          ),
          if (activeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.text,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.bg, width: 2),
                ),
                child: Text(
                  '$activeCount',
                  style: T.micro.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: c.bg,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chips dos filtros ativos (exibidos apenas quando há filtro aplicado).
class _ActiveFiltersRow extends StatelessWidget {
  final PayCard? card;
  final Category? category;
  final VoidCallback onClearCard;
  final VoidCallback onClearCategory;
  final VoidCallback onClearAll;
  const _ActiveFiltersRow({
    required this.card,
    required this.category,
    required this.onClearCard,
    required this.onClearCategory,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        if (card != null)
          ChipButton(
            card!.last4.isNotEmpty ? '${card!.name} •${card!.last4}' : card!.name,
            dot: Color(card!.color),
            selected: true,
            onTap: onClearCard,
          ),
        if (category != null)
          ChipButton(
            category!.label,
            icon: category!.icon,
            selected: true,
            onTap: onClearCategory,
          ),
        ChipButton(
          'Limpar',
          icon: LucideIcons.x,
          onTap: onClearAll,
        ),
      ],
    );
  }
}

/// Bottom sheet de filtros compartilhado entre Extrato e Busca.
Future<void> _showExtratoFilterSheet(
  BuildContext context, {
  required Set<String> usedCats,
  required String? selectedCard,
  required String? selectedCat,
  required void Function(String? card, String? cat) onApply,
}) {
  final s = context.storeRead;
  var tmpCard = selectedCard;
  var tmpCat = selectedCat;
  final availableCats = categories
      .where((x) => usedCats.contains(x.id) || x.id == selectedCat)
      .toList();

  return showSheet<void>(
    context,
    edgeToEdge: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final c = ctx.c;
        final chipBg = c.isDark ? c.cardAlt : c.surfaceLow;
        final hasAny = tmpCard != null || tmpCat != null;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            4,
            Space.gutter,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtros',
                      style: T.title.copyWith(
                        color: c.text,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (hasAny)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.sm,
                      ),
                      onPressed: () => set(() {
                        tmpCard = null;
                        tmpCat = null;
                      }),
                      child: Text(
                        'Limpar',
                        style: T.labelStrong.copyWith(color: c.primary),
                      ),
                    ),
                  RoundIconButton(
                    LucideIcons.x,
                    size: 36,
                    bg: chipBg,
                    label: 'Fechar',
                    onTap: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (s.data.cards.isNotEmpty) ...[
                const SizedBox(height: Space.base),
                Text(
                  'Contas e cartões',
                  style: T.label.copyWith(
                    color: c.textSecondary,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    ChipButton(
                      'Todas',
                      bg: chipBg,
                      selected: tmpCard == null,
                      onTap: () => set(() => tmpCard = null),
                    ),
                    for (final k in s.data.cards)
                      ChipButton(
                        k.last4.isNotEmpty ? '${k.name} •${k.last4}' : k.name,
                        dot: Color(k.color),
                        bg: chipBg,
                        selected: tmpCard == k.id,
                        onTap: () => set(
                          () => tmpCard = tmpCard == k.id ? null : k.id,
                        ),
                      ),
                  ],
                ),
              ],
              if (availableCats.isNotEmpty) ...[
                const SizedBox(height: Space.base),
                Text(
                  'Categorias',
                  style: T.label.copyWith(
                    color: c.textSecondary,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    ChipButton(
                      'Todas',
                      bg: chipBg,
                      selected: tmpCat == null,
                      onTap: () => set(() => tmpCat = null),
                    ),
                    for (final cat in availableCats)
                      ChipButton(
                        cat.label,
                        icon: cat.icon,
                        bg: chipBg,
                        selected: tmpCat == cat.id,
                        onTap: () => set(
                          () => tmpCat = tmpCat == cat.id ? null : cat.id,
                        ),
                      ),
                  ],
                ),
              ],
              if (s.data.cards.isEmpty && availableCats.isEmpty) ...[
                const SizedBox(height: Space.base),
                Text(
                  'Nenhum filtro disponível para este ciclo.',
                  style: T.label.copyWith(
                    color: c.textSecondary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
              const SizedBox(height: Space.lg),
              PillButton(
                'Aplicar',
                onTap: () {
                  onApply(tmpCard, tmpCat);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Página dedicada de busca dentro do Extrato (com transição Hero da barra de
/// busca e o mesmo modelo de filtros em botão + sheet).
class ExtratoSearchScreen extends StatefulWidget {
  final Cycle cycle;
  final String? initialCard;
  final String? initialCat;
  const ExtratoSearchScreen({
    super.key,
    required this.cycle,
    this.initialCard,
    this.initialCat,
  });

  @override
  State<ExtratoSearchScreen> createState() => _ExtratoSearchScreenState();
}

class _ExtratoSearchScreenState extends State<ExtratoSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _q = '';
  bool _allCycles = false;
  late String? _cat = widget.initialCat;
  late String? _card = widget.initialCard;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final pad = sidePadding(context);

    final base = _allCycles
        ? [...s.data.expenses]
        : f.expensesIn(widget.cycle);
    final activeCard = _card == null ? null : s.card(_card);
    final effectiveCardId = activeCard?.id;
    final activeCat = _cat == null ? null : categoryById(_cat!);
    final qFold = foldText(_q);
    var results = base;
    if (_cat != null) {
      results = results.where((e) => e.categoryId == _cat).toList();
    }
    if (effectiveCardId != null) {
      results = results.where((e) => e.cardId == effectiveCardId).toList();
    }
    if (qFold.isNotEmpty) {
      results = results.where((e) {
        final cardName = s.card(e.cardId)?.name ?? '';
        return foldText(e.name).contains(qFold) ||
            foldText(e.category.label).contains(qFold) ||
            foldText(cardName).contains(qFold);
      }).toList();
    }
    results.sort((a, b) => b.date.compareTo(a.date));
    final total = results.fold<int>(0, (t, e) => t + e.cents);
    final usedCats = base.map((e) => e.categoryId).toSet();
    final activeFilterCount =
        (_cat != null ? 1 : 0) + (effectiveCardId != null ? 1 : 0);

    return SheetScaler(
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            PinnedCupertinoBar(
              height: 64,
              builder: (ctx, _) => Row(
                children: [
                  const BackChevron(),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Hero(
                      tag: _searchHeroTag,
                      flightShuttleBuilder: _searchShuttle,
                      child: AppField(
                        controller: _ctrl,
                        focusNode: _focus,
                        placeholder: 'Buscar gasto ou categoria',
                        pill: true,
                        prefix: Icon(
                          LucideIcons.search,
                          size: 18,
                          color: c.textSecondary,
                        ),
                        suffix: _q.isEmpty
                            ? null
                            : Pressable(
                                onTap: () {
                                  _ctrl.clear();
                                  setState(() => _q = '');
                                },
                                child: Icon(
                                  LucideIcons.x,
                                  size: 18,
                                  color: c.textSecondary,
                                ),
                              ),
                        onChanged: (v) => setState(() => _q = v.trim()),
                        action: TextInputAction.search,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  _FilterButton(
                    activeCount: activeFilterCount,
                    onTap: () => _showExtratoFilterSheet(
                      context,
                      usedCats: usedCats,
                      selectedCard: _card,
                      selectedCat: _cat,
                      onApply: (card, cat) => setState(() {
                        _card = card;
                        _cat = cat;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, 0),
              sliver: SliverList.list(
                children: [
                  Segmented<bool>(
                    value: _allCycles,
                    options: {
                      false: widget.cycle.label(),
                      true: 'Todos os ciclos',
                    },
                    onChanged: (v) => setState(() => _allCycles = v),
                  ),
                  if (activeCard != null || activeCat != null) ...[
                    const SizedBox(height: Space.md),
                    _ActiveFiltersRow(
                      card: activeCard,
                      category: activeCat,
                      onClearCard: () => setState(() => _card = null),
                      onClearCategory: () => setState(() => _cat = null),
                      onClearAll: () => setState(() {
                        _cat = null;
                        _card = null;
                      }),
                    ),
                  ],
                ],
              ),
            ),
            if (results.isEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  Space.base,
                  pad,
                  Space.xl + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverToBoxAdapter(
                  child: EmptyState(
                    icon: LucideIcons.search,
                    title: 'Nenhum resultado',
                    message: _q.isNotEmpty
                        ? 'Não encontrei gastos para "$_q".'
                        : 'Nenhum lançamento encontrado com esse filtro.',
                    action: !_allCycles && _q.isNotEmpty
                        ? 'Buscar em todos os ciclos'
                        : (activeFilterCount > 0 ? 'Limpar filtros' : null),
                    onAction: !_allCycles && _q.isNotEmpty
                        ? () => setState(() => _allCycles = true)
                        : (activeFilterCount > 0
                              ? () => setState(() {
                                  _cat = null;
                                  _card = null;
                                })
                              : null),
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, Space.md, pad, Space.xs),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${results.length} ${results.length == 1 ? 'resultado' : 'resultados'}',
                            style: T.bodyMedium.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          fmtMoney(total, hidden: hidden),
                          style: T.smallStrong.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  0,
                  pad,
                  Space.xl + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverListGroup(
                  itemCount: results.length,
                  itemBuilder: (_, i) =>
                      ExpenseRow(e: results[i], f: f, hidden: hidden),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ExpenseRow extends StatelessWidget {
  final Expense e;
  final Finance f;
  final bool hidden;
  final bool hideCategory;
  const ExpenseRow({
    super.key,
    required this.e,
    required this.f,
    required this.hidden,
    this.hideCategory = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = context.storeRead.card(e.cardId);
    final parts = <String>[
      if (!hideCategory) e.category.label,
      if (e.isRecurring && e.endDate != null)
        'até ${DateFormat('MM/yy').format(e.endDate!)}'
      else if (hideCategory && e.isRecurring && card == null)
        'Todo mês',
      if (card != null) card.name,
    ];
    final meta = parts.isEmpty ? null : parts.take(2).join(' · ');
    return ListRow(
      leading: BrandLogo(
        name: e.name,
        icon: e.category.icon,
        color: e.category.color,
        size: 40,
      ),
      title: e.name,
      subtitle: meta,
      value: fmtMoney(e.cents, hidden: hidden),
      valueColor: e.cents < 0 ? c.positive : null,
      onTap: () => showExpenseActions(context, e),
    );
  }
}
