import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/brands.dart';
import '../../data/finance.dart';
import '../../data/models.dart';
import '../../data/store.dart';
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
  final ValueNotifier<ExtratoFilter?> filter;
  const ExtratoScreen({super.key, required this.filter});
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
    widget.filter.addListener(_applyExternal);
  }

  void _applyExternal() {
    final f = widget.filter.value;
    if (f == null) return;
    setState(() {
      _offset = 0;
      _cat = f.categoryId;
      _card = f.cardId;
    });
    widget.filter.value = null;
  }

  @override
  void dispose() {
    widget.filter.removeListener(_applyExternal);
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
    var items = allInCycle;
    if (_cat != null) items = items.where((e) => e.categoryId == _cat).toList();
    if (_card != null) items = items.where((e) => e.cardId == _card).toList();

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

    return Stack(
      children: [
        const GlowBackground(height: 440),
        // Véu suave na cor do fundo (escuro no dark, claro no light)
        IgnorePointer(
          child: SizedBox(
            height: 440,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.bg.withValues(alpha: c.isDark ? 0.48 : 0.54),
                    c.bg.withValues(alpha: c.isDark ? 0.68 : 0.72),
                    c.bg.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            PinnedCupertinoBar(
              height: 60,
              builder: (ctx, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      'Extrato',
                      style: T.pageTitle.copyWith(color: c.text),
                    ),
                  ),
                  RoundIconButton(
                    LucideIcons.plus,
                    size: 44,
                    label: 'Adicionar gasto',
                    bg: c.primary,
                    fg: c.onPrimary,
                    onTap: () => openAddExpense(context),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, 0),
              sliver: SliverList.list(
                children: [
                  Segmented<int>(
                    value: _kind,
                    options: const {0: 'Todos', 1: 'Recorrentes', 2: 'Únicos'},
                    onChanged: (v) => setState(() => _kind = v),
                  ),
                  const SizedBox(height: Space.base),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RoundIconButton(
                        LucideIcons.chevronLeft,
                        size: 36,
                        bg: c.cardAlt,
                        label: 'Ciclo anterior',
                        onTap: () => setState(() => _offset--),
                      ),
                      const SizedBox(width: Space.md),
                      BlurSwitcher(
                        alignment: Alignment.center,
                        child: Column(
                          key: ValueKey(cy.key),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cy.label(),
                              style: T.bodyStrong.copyWith(color: c.text),
                            ),
                            Text(
                              _range(cy),
                              style: T.small.copyWith(color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      RoundIconButton(
                        LucideIcons.chevronRight,
                        size: 36,
                        bg: c.cardAlt,
                        label: 'Próximo ciclo',
                        onTap: _offset >= 12
                            ? null
                            : () => setState(() => _offset++),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.lg),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Total do ciclo',
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
                        if (salary > 0)
                          Text(
                            'de ${fmtMoney(salary, hidden: hidden)}',
                            style: T.small.copyWith(color: c.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  // Gatilho de busca em pílula: abre página dedicada de busca
                  Pressable(
                    semanticLabel: 'Buscar gasto ou categoria',
                    scale: 0.985,
                    onTap: () => push(
                      context,
                      ExtratoSearchScreen(cycle: cy),
                    ),
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
                          Text(
                            'Buscar gasto ou categoria',
                            style: T.body.copyWith(color: c.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Filtros horizontais
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(pad, Space.md, pad, Space.xs),
                  children: [
                    ChipButton(
                      'Todos',
                      selected: _cat == null && _card == null,
                      onTap: () => setState(() => _cat = _card = null),
                    ),
                    for (final k in s.data.cards) ...[
                      const SizedBox(width: Space.sm),
                      ChipButton(
                        k.last4.isNotEmpty ? '${k.name} •${k.last4}' : k.name,
                        dot: Color(k.color),
                        selected: _card == k.id,
                        onTap: () =>
                            setState(() => _card = _card == k.id ? null : k.id),
                      ),
                    ],
                    for (final cat in categories.where(
                      (x) => usedCats.contains(x.id) || x.id == _cat,
                    )) ...[
                      const SizedBox(width: Space.sm),
                      ChipButton(
                        cat.label,
                        icon: cat.icon,
                        selected: _cat == cat.id,
                        onTap: () =>
                            setState(() => _cat = _cat == cat.id ? null : cat.id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                pad,
                Space.sm,
                pad,
                navClearance(context),
              ),
              sliver: SliverList.list(
                children: [
                  if (items.isEmpty) ...[
                    const SizedBox(height: Space.sm),
                    EmptyState(
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
                  ] else if (_kind == 0) ...[
                    // Aba "Todos": recorrentes e únicos juntos numa só lista
                    ListGroup(
                      title: 'Gastos',
                      trailing: Text(
                        fmtMoney(total, hidden: hidden),
                        style: T.smallStrong.copyWith(color: c.textSecondary),
                      ),
                      children: [
                        for (final e in unified)
                          ExpenseRow(e: e, f: f, hidden: hidden),
                      ],
                    ),
                  ] else if (_kind == 1) ...[
                    // Aba "Recorrentes"
                    ListGroup(
                      title: 'Recorrentes',
                      trailing: Text(
                        fmtMoney(
                          recurringOnly.fold(0, (t, e) => t + e.cents),
                          hidden: hidden,
                        ),
                        style: T.smallStrong.copyWith(color: c.textSecondary),
                      ),
                      children: [
                        for (final e in recurringOnly)
                          ExpenseRow(e: e, f: f, hidden: hidden),
                      ],
                    ),
                  ] else ...[
                    // Aba "Únicos" agrupada por dia
                    for (final day in byDay.keys)
                      ListGroup(
                        title: _dayLabel(day),
                        trailing: Text(
                          fmtMoney(
                            byDay[day]!.fold(0, (t, e) => t + e.cents),
                            hidden: hidden,
                          ),
                          style: T.smallStrong.copyWith(color: c.textSecondary),
                        ),
                        children: [
                          for (final e in byDay[day]!)
                            ExpenseRow(e: e, f: f, hidden: hidden),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _range(Cycle cy) {
    final last = cy.end.subtract(const Duration(days: 1));
    return '${cy.start.day}/${cy.start.month} – ${last.day}/${last.month}';
  }

  String _dayLabel(DateTime d) {
    final today = dateOnly(DateTime.now());
    if (sameDay(d, today)) return 'Hoje';
    if (sameDay(d, today.subtract(const Duration(days: 1)))) return 'Ontem';
    final raw = DateFormat("EEEE, d 'de' MMM", 'pt_BR').format(d);
    return raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
  }
}

/// Página dedicada de busca dentro do Extrato (sem competir com a navbar flutuante).
class ExtratoSearchScreen extends StatefulWidget {
  final Cycle cycle;
  const ExtratoSearchScreen({super.key, required this.cycle});

  @override
  State<ExtratoSearchScreen> createState() => _ExtratoSearchScreenState();
}

class _ExtratoSearchScreenState extends State<ExtratoSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _q = '';
  bool _allCycles = false;
  String? _cat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final qFold = foldText(_q);
    var results = base;
    if (_cat != null) {
      results = results.where((e) => e.categoryId == _cat).toList();
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
                    child: AppField(
                      controller: _ctrl,
                      focusNode: _focus,
                      placeholder: 'Buscar gasto, categoria ou cartão',
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
                ],
              ),
            ),
            if (usedCats.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(pad, Space.md, pad, Space.xs),
                    children: [
                      ChipButton(
                        'Todas',
                        selected: _cat == null,
                        onTap: () => setState(() => _cat = null),
                      ),
                      for (final cat in categories.where(
                        (x) => usedCats.contains(x.id) || x.id == _cat,
                      )) ...[
                        const SizedBox(width: Space.sm),
                        ChipButton(
                          cat.label,
                          icon: cat.icon,
                          selected: _cat == cat.id,
                          onTap: () => setState(
                            () => _cat = _cat == cat.id ? null : cat.id,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.xl),
              sliver: SliverList.list(
                children: [
                  if (results.isEmpty)
                    EmptyState(
                      icon: LucideIcons.search,
                      title: 'Nenhum resultado',
                      message: _q.isNotEmpty
                          ? 'Não encontrei gastos para "$_q".'
                          : 'Nenhum lançamento encontrado com esse filtro.',
                      action: !_allCycles && _q.isNotEmpty
                          ? 'Buscar em todos os ciclos'
                          : null,
                      onAction: !_allCycles && _q.isNotEmpty
                          ? () => setState(() => _allCycles = true)
                          : null,
                    )
                  else
                    ListGroup(
                      title:
                          '${results.length} ${results.length == 1 ? 'resultado' : 'resultados'}',
                      trailing: Text(
                        fmtMoney(total, hidden: hidden),
                        style: T.smallStrong.copyWith(color: c.textSecondary),
                      ),
                      children: [
                        for (final e in results)
                          ExpenseRow(e: e, f: f, hidden: hidden),
                      ],
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

class ExpenseRow extends StatelessWidget {
  final Expense e;
  final Finance f;
  final bool hidden;
  const ExpenseRow({
    super.key,
    required this.e,
    required this.f,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final card = context.storeRead.card(e.cardId);
    final meta = [
      e.category.label,
      if (e.isRecurring)
        e.endDate == null
            ? 'todo mês'
            : 'até ${DateFormat('MM/yy').format(e.endDate!)}',
      if (card != null)
        card.last4.isNotEmpty ? '${card.name} •${card.last4}' : card.name,
    ].join(' · ');
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
