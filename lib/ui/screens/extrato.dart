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
      items = items.where((e) => e.name.toLowerCase().contains(q) || e.category.label.toLowerCase().contains(q)).toList();
    }

    final recurring = items.where((e) => e.isRecurring).toList()..sort((a, b) => b.cents.compareTo(a.cents));
    final once = items.where((e) => !e.isRecurring).toList()..sort((a, b) => b.date.compareTo(a.date));
    final byDay = <DateTime, List<Expense>>{};
    for (final e in once) {
      byDay.putIfAbsent(dateOnly(e.date), () => []).add(e);
    }

    final total = items.fold<int>(0, (t, e) => t + e.cents);
    final salary = f.salaryFor(cy);
    final pad = sidePadding(context);
    final usedCats = allInCycle.map((e) => e.categoryId).toSet();

    // Agrupa categorias do recorte atual para a barra segmentada no topo.
    final catTotals = <String, int>{};
    for (final e in items) {
      catTotals[e.categoryId] = (catTotals[e.categoryId] ?? 0) + e.cents;
    }
    final topCats = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        PinnedCupertinoBar(
          height: 60,
          builder: (ctx, _) => Row(
            children: [
              Expanded(
                child: Text('Extrato', style: T.title.copyWith(color: c.text, fontSize: 26)),
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
              // ── Card de consumo do ciclo (inspirado no design de barra segmentada)
              Container(
                padding: const EdgeInsets.all(Space.base),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(Space.radiusCard),
                  border: Border.all(color: c.border.withValues(alpha: c.isDark ? 0.5 : 0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Navegador de ciclo compacto no topo do card
                    Row(
                      children: [
                        RoundIconButton(
                          LucideIcons.chevronLeft,
                          size: 44,
                          bg: c.cardAlt,
                          label: 'Ciclo anterior',
                          onTap: () => setState(() => _offset--),
                        ),
                        Expanded(
                          child: BlurSwitcher(
                            alignment: Alignment.center,
                            child: Column(
                              key: ValueKey(cy.key),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(cy.label(), style: T.bodyStrong.copyWith(color: c.text)),
                                Text(_range(cy), style: T.small.copyWith(color: c.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                        RoundIconButton(
                          LucideIcons.chevronRight,
                          size: 44,
                          bg: c.cardAlt,
                          label: 'Próximo ciclo',
                          onTap: _offset >= 12 ? null : () => setState(() => _offset++),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.base),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        CountingMoney(
                          cents: total,
                          builder: (v) => MoneyText(v, hidden: hidden, style: T.title.copyWith(fontSize: 28)),
                        ),
                        if (salary > 0) ...[
                          const SizedBox(width: Space.sm),
                          Flexible(
                            child: Text(
                              'de ${fmtMoney(salary, hidden: hidden)}',
                              style: T.label.copyWith(color: c.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (total > 0 && topCats.isNotEmpty) ...[
                      const SizedBox(height: Space.md),
                      // Barra segmentada em pílulas arredondadas por categoria
                      SizedBox(
                        height: 10,
                        child: Row(
                          children: [
                            for (var k = 0; k < topCats.length && k < 4; k++) ...[
                              if (k > 0) const SizedBox(width: Space.xs),
                              Expanded(
                                flex: (topCats[k].value * 100 ~/ total).clamp(6, 100),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: categoryById(topCats[k].key).color,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.md),
                      Wrap(
                        spacing: Space.md,
                        runSpacing: Space.xs,
                        children: [
                          for (var k = 0; k < topCats.length && k < 3; k++)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: categoryById(topCats[k].key).color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: Space.xs),
                                Text(
                                  '${categoryById(topCats[k].key).label} ${(topCats[k].value / total * 100).round()}%',
                                  style: T.small.copyWith(color: c.textSecondary),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        '${items.length} lançamentos neste ciclo',
                        style: T.small.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              AppField(
                controller: _search,
                placeholder: 'Buscar gasto ou categoria',
                prefix: Icon(LucideIcons.search, size: 18, color: c.textSecondary),
                suffix: _q.isEmpty
                    ? null
                    : Pressable(
                        onTap: () {
                          _search.clear();
                          setState(() => _q = '');
                        },
                        child: Icon(LucideIcons.x, size: 18, color: c.textSecondary),
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
                ChipButton('Todos', selected: _cat == null && _card == null, onTap: () => setState(() => _cat = _card = null)),
                for (final k in s.data.cards) ...[
                  const SizedBox(width: Space.sm),
                  ChipButton(
                    k.last4.isNotEmpty ? '${k.name} •${k.last4}' : k.name,
                    dot: Color(k.color),
                    selected: _card == k.id,
                    onTap: () => setState(() => _card = _card == k.id ? null : k.id),
                  ),
                ],
                for (final cat in categories.where((x) => usedCats.contains(x.id) || x.id == _cat)) ...[
                  const SizedBox(width: Space.sm),
                  ChipButton(
                    cat.label,
                    icon: cat.icon,
                    selected: _cat == cat.id,
                    onTap: () => setState(() => _cat = _cat == cat.id ? null : cat.id),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, navClearance(context)),
          sliver: SliverList.list(
            children: [
              if (items.isEmpty) ...[
                const SizedBox(height: Space.sm),
                EmptyState(
                  icon: LucideIcons.receipt,
                  title: _q.isNotEmpty || _cat != null || _card != null ? 'Nenhum gasto com esse filtro' : 'Sem gastos neste ciclo',
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
                SectionHeader(
                  'Recorrentes',
                  trailing: Text(
                    fmtMoney(recurring.fold(0, (t, e) => t + e.cents), hidden: hidden),
                    style: T.smallStrong.copyWith(color: c.textSecondary),
                  ),
                ),
                _group(context, [for (final e in recurring) ExpenseRow(e: e, f: f, hidden: hidden)]),
              ],
              for (final day in byDay.keys) ...[
                SectionHeader(
                  _dayLabel(day),
                  trailing: Text(
                    fmtMoney(byDay[day]!.fold(0, (t, e) => t + e.cents), hidden: hidden),
                    style: T.smallStrong.copyWith(color: c.textSecondary),
                  ),
                ),
                _group(context, [for (final e in byDay[day]!) ExpenseRow(e: e, f: f, hidden: hidden)]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, List<Widget> rows) {
    final c = context.c;
    final n = rows.length;
    return Column(
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: Space.xs),
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? 22 : 8),
                bottom: Radius.circular(i == n - 1 ? 22 : 8),
              ),
              border: Border.all(color: c.border.withValues(alpha: c.isDark ? 0.45 : 0.65)),
            ),
            clipBehavior: Clip.antiAlias,
            child: rows[i],
          ),
        ],
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
  const ExpenseRow({super.key, required this.e, required this.f, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.storeRead;
    final card = s.card(e.cardId);
    final meta = [
      e.category.label,
      if (e.isRecurring) e.endDate == null ? 'todo mês' : 'até ${DateFormat('MM/yy').format(e.endDate!)}',
      if (card != null) card.last4.isNotEmpty ? '${card.name} •${card.last4}' : card.name,
    ].join(' · ');
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: c.negativeSoft,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        child: Icon(LucideIcons.trash2, color: c.negative),
      ),
      confirmDismiss: (_) => confirm(
        context,
        title: 'Excluir "${e.name}"?',
        message: e.isRecurring ? 'Some de todos os ciclos, inclusive os anteriores.' : null,
        action: 'Excluir',
      ),
      onDismissed: (_) {
        s.deleteExpense(e.id);
        toast(context, 'Gasto excluído', icon: LucideIcons.trash2);
      },
      child: Pressable(
        scale: 0.985,
        onTap: () => showExpenseActions(context, e),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.base, vertical: Space.md),
          child: Row(
            children: [
              IconBadge(e.category.icon, e.category.color, size: 42),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: T.bodyStrong.copyWith(color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      meta,
                      style: T.small.copyWith(color: c.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(
                fmtMoney(e.cents, hidden: hidden),
                style: T.bodyStrong.copyWith(color: e.cents < 0 ? c.positive : c.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detalhe rápido de um gasto com as ações possíveis.
Future<void> showExpenseActions(BuildContext context, Expense e) async {
  final s = context.storeRead;
  final f = s.f;
  final active = f.expenseActive(e, f.current);
  final hidden = s.data.hideValues;
  final a = await actionSheet<String>(
    context,
    title: '${e.name} · ${fmtMoney(e.cents, hidden: hidden)}',
    message: e.isRecurring
        ? 'Recorrente desde ${DateFormat("MMMM 'de' y", 'pt_BR').format(e.date)}${e.endDate != null ? ', até ${DateFormat('dd/MM/yyyy').format(e.endDate!)}' : ''}.'
        : 'Gasto único em ${DateFormat('dd/MM/yyyy').format(e.date)}.',
    actions: [
      const SheetAction('Editar', 'edit', icon: LucideIcons.pencil),
      const SheetAction('Duplicar para hoje', 'dup', icon: LucideIcons.copy),
      if (e.isRecurring && active && (e.endDate == null || e.endDate!.isAfter(f.current.end)))
        const SheetAction('Parar de repetir após este ciclo', 'end', icon: LucideIcons.repeat),
      const SheetAction('Excluir', 'delete', destructive: true, icon: LucideIcons.trash2),
    ],
  );
  if (!context.mounted) return;
  switch (a) {
    case 'edit':
      openEditExpense(context, e);
    case 'dup':
      s.addExpense(Expense(name: e.name, cents: e.cents, categoryId: e.categoryId, cardId: e.cardId, date: DateTime.now()));
      toast(context, 'Gasto duplicado');
    case 'end':
      s.endRecurring(e.id);
      toast(context, 'Não vai repetir no próximo ciclo');
    case 'delete':
      final ok = await confirm(
        context,
        title: 'Excluir "${e.name}"?',
        message: e.isRecurring
            ? 'Some de todos os ciclos, inclusive os anteriores. Para manter o histórico, use "Parar de repetir".'
            : null,
        action: 'Excluir',
      );
      if (ok && context.mounted) {
        s.deleteExpense(e.id);
        toast(context, 'Gasto excluído', icon: LucideIcons.trash2);
      }
  }
}
