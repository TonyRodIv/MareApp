import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'add_expense.dart';
import 'cards.dart';

/// Detalhe de um gasto em bottom sheet: cabeçalho com ícone e fechar, valor
/// grande, três ações rápidas e a lista "Detalhes" (cartão, tipo, ciclo, situação).
Future<void> showExpenseActions(BuildContext context, Expense e) =>
    showIosSheet<void>(
      context,
      builder: (_) => ExpenseSheet(expenseId: e.id, host: context),
    );

class ExpenseSheet extends StatelessWidget {
  final String expenseId;
  final BuildContext
  host; // contexto que continua vivo depois de fechar o sheet
  const ExpenseSheet({super.key, required this.expenseId, required this.host});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final e = s.data.expenses.where((x) => x.id == expenseId).firstOrNull;
    if (e == null) return const SizedBox(height: 120);
    final f = s.f;
    final hidden = s.data.hideValues;
    final cat = e.category;
    final card = s.card(e.cardId);
    final cur = f.current;
    final active = f.expenseActive(e, cur);
    final entryCycle = f.cycleOf(e.date);
    final cycle = e.isRecurring ? cur : entryCycle;
    final total = f.expensesTotal(cycle);
    final share = total > 0 ? (e.cents / total).clamp(0.0, 1.0) : 0.0;
    final ended =
        e.isRecurring &&
        e.endDate != null &&
        f.cycleOf(e.endDate!).key < cur.key;
    final canEnd =
        e.isRecurring &&
        active &&
        (e.endDate == null || f.cycleOf(e.endDate!).key > cur.key);

    final status = e.isRecurring
        ? (ended
              ? 'Encerrado'
              : (e.endDate == null
                    ? 'Ativo'
                    : 'Ativo até ${DateFormat('MM/yy').format(e.endDate!)}'))
        : (entryCycle.key == cur.key
              ? 'Neste ciclo'
              : (entryCycle.key < cur.key ? 'Ciclo anterior' : 'Ciclo futuro'));
    final dateLabel = e.isRecurring
        ? 'Todo ciclo, desde ${DateFormat("d 'de' MMM 'de' y", 'pt_BR').format(e.date)}'
        : _cap(DateFormat("EEE, d 'de' MMM 'de' y", 'pt_BR').format(e.date));

    void close() => Navigator.of(context).pop();

    return SheetBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho: o fechar fica mais alto, à direita; logo e nome entram um
          // pouco abaixo, fora da linha do botão (como na referência).
          Reveal(
            blur: false,
            baseDelay: Duration.zero,
            child: SizedBox(
              height: 76,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 48,
                    top: 20,
                    child: Row(
                      children: [
                        BrandLogo(
                          name: e.name,
                          icon: cat.icon,
                          color: cat.color,
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.name,
                                style: T.headline.copyWith(color: c.text),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                cat.label,
                                style: T.label.copyWith(color: c.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: RoundIconButton(
                      LucideIcons.x,
                      size: 36,
                      bg: c.cardAlt,
                      label: 'Fechar',
                      onTap: close,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Valor e data
          Reveal(
            blur: false,
            index: 1,
            baseDelay: Duration.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoneyText(
                  e.cents.abs(),
                  hidden: hidden,
                  style: T.displayLg,
                  color: e.cents < 0 ? c.positive : null,
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  style: T.small.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Ações rápidas circulares (mesmo padrão das ações de Caixinhas)
          Reveal(
            blur: false,
            index: 2,
            baseDelay: Duration.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAction(
                  icon: LucideIcons.pencil,
                  label: 'Editar',
                  size: canEnd ? 56 : 62,
                  onTap: () {
                    close();
                    openEditExpense(host, e);
                  },
                ),
                CircleAction(
                  icon: LucideIcons.copy,
                  label: 'Duplicar',
                  size: canEnd ? 56 : 62,
                  onTap: () {
                    s.addExpense(
                      Expense(
                        name: e.name,
                        cents: e.cents,
                        categoryId: e.categoryId,
                        cardId: e.cardId,
                        date: DateTime.now(),
                      ),
                    );
                    close();
                    toast(host, 'Duplicado para hoje');
                  },
                ),
                if (canEnd)
                  CircleAction(
                    icon: LucideIcons.calendarOff,
                    label: 'Encerrar',
                    size: 56,
                    onTap: () {
                      s.endRecurring(e.id);
                      close();
                      toast(host, 'Não repete a partir do próximo ciclo');
                    },
                  ),
                CircleAction(
                  icon: LucideIcons.trash2,
                  label: 'Excluir',
                  danger: true,
                  size: canEnd ? 56 : 62,
                  onTap: () => _delete(context, e, close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Detalhes
          Text(
            'Detalhes',
            style: T.headline.copyWith(color: c.text),
          ),
          const SizedBox(height: 6),
          _Row(
            'Cartão',
            trailing: card == null
                ? _val(c, 'Sem cartão')
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BrandBadge(brand: card.brand),
                      const SizedBox(width: 8),
                      Text(
                        '•• ${card.last4}',
                        style: T.bodyStrong.copyWith(color: c.text),
                      ),
                    ],
                  ),
          ),
          _Row(
            'Tipo',
            trailing: _val(c, e.isRecurring ? 'Recorrente' : 'Único'),
          ),
          _Row('Categoria', trailing: _val(c, cat.label)),
          _Row('Ciclo', trailing: _val(c, cycle.label())),
          if (e.isRecurring)
            _Row(
              'Término',
              trailing: _val(
                c,
                e.endDate == null
                    ? 'Sem data final'
                    : DateFormat('dd/MM/yyyy').format(e.endDate!),
              ),
            ),
          _Row(
            'Situação',
            trailing: _val(
              c,
              status,
              color: ended ? c.textSecondary : c.positive,
            ),
          ),
          const SizedBox(height: 18),

          // Peso no ciclo
          Container(
            padding: const EdgeInsets.all(Space.base),
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: c.borderStrong),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Peso nos gastos de ${cycle.label()}',
                        style: T.small.copyWith(color: c.textSecondary),
                      ),
                    ),
                    Text(
                      '${(share * 100).round()}%',
                      style: T.bodyStrong.copyWith(color: c.text),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SpringBar(
                  fraction: share,
                  color: c.tone(cat.color),
                  track: c.surfaceLow,
                  height: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _cap(String v) =>
      v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

  static Widget _val(AppColors c, String t, {Color? color}) => Text(
    t,
    style: T.bodyStrong.copyWith(color: color ?? c.text),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  Future<void> _delete(
    BuildContext context,
    Expense e,
    VoidCallback close,
  ) async {
    final s = context.storeRead;
    final ok = await confirm(
      context,
      title: 'Excluir "${e.name}"?',
      message: e.isRecurring
          ? 'Some de todos os ciclos, inclusive dos anteriores. Para manter o histórico, use Encerrar.'
          : null,
      action: 'Excluir',
    );
    if (!ok) return;
    s.deleteExpense(e.id);
    close();
    if (host.mounted) toast(host, 'Gasto excluído', icon: LucideIcons.trash2);
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _Row(this.label, {required this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Text(label, style: T.body.copyWith(color: c.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}
