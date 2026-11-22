import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
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

/// Extrato redesenhado: card de consumo com barra segmentada por categoria,
/// navegação de ciclo integrada, filtros rápidos e lançamentos espaçados.
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
  String _q = '';
  int _kind = 0; // 0 todos, 1 recorrentes, 2 únicos
  final _search = TextEditingController();

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
    _search.dispose();
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
    if (_q.isNotEmpty) {
      final q = _q.toLowerCase();
      items = items
          .where(
            (e) =>
                e.name.toLowerCase().contains(q) ||
                e.category.label.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_kind == 1) items = items.where((e) => e.isRecurring).toList();
    if (_kind == 2) items = items.where((e) => !e.isRecurring).toList();
    final recurring = items.where((e) => e.isRecurring).toList()
      ..sort((a, b) => b.cents.compareTo(a.cents));
    final once = items.where((e) => !e.isRecurring).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final byDay = <DateTime, List<Expense>>{};
    for (final e in once) {
      byDay.putIfAbsent(dateOnly(e.date), () => []).add(e);
    }

    final total = items.fold<int>(0, (t, e) => t + e.cents);
    final salary = f.salaryFor(cy);
    final pad = sidePadding(context);
    final usedCats = allInCycle.map((e) => e.categoryId).toSet();

    return Stack(
      children: [
        const GlowBackground(height: 440),
        // Véu suave na cor do fundo (escuro no dark, claro no light) para deixar
        // o brilho do Extrato mais contido e elegante.
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
              // Tipo de lançamento: pílula segmentada, como na referência
              Segmented<int>(
                value: _kind,
                options: const {0: 'Todos', 1: 'Recorrentes', 2: 'Únicos'},
                onChanged: (v) => setState(() => _kind = v),
              ),
              const SizedBox(height: Space.base),
              // Ciclo: navegação compacta e centralizada
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
              // Total do recorte, grande e centralizado
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
              AppField(
                controller: _search,
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
                          _search.clear();
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
                  title: _q.isNotEmpty || _cat != null || _card != null
                      ? 'Nenhum gasto com esse filtro'
                      : 'Sem gastos neste ciclo',
                  message: _q.isNotEmpty || _cat != null || _card != null
                      ? 'Remova os filtros para ver todos os lançamentos'
                      : 'Os gastos registrados aparecem aqui por dia',
                  action: _q.isNotEmpty || _cat != null || _card != null
                      ? 'Limpar filtros'
                      : (_offset == 0 ? 'Adicionar gasto' : null),
                  onAction: _q.isNotEmpty || _cat != null || _card != null
                      ? () {
                          _search.clear();
                          setState(() {
                            _q = '';
                            _cat = null;
                            _card = null;
                          });
                        }
                      : () => openAddExpense(context),
                ),
              ],
              if (recurring.isNotEmpty) ...[
                ListGroup(
                  title: 'Recorrentes',
                  trailing: Text(
                    fmtMoney(
                      recurring.fold(0, (t, e) => t + e.cents),
                      hidden: hidden,
                    ),
                    style: T.smallStrong.copyWith(color: c.textSecondary),
                  ),
                  children: [
                    for (final e in recurring)
                      ExpenseRow(e: e, f: f, hidden: hidden),
                  ],
                ),
              ],
              for (final day in byDay.keys) ...[
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
