import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/brands.dart';
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

class ExpenseSheet extends StatefulWidget {
  final String expenseId;
  final BuildContext
  host; // contexto que continua vivo depois de fechar o sheet
  const ExpenseSheet({super.key, required this.expenseId, required this.host});

  @override
  State<ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<ExpenseSheet> {
  late String _id = widget.expenseId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final e = s.data.expenses.where((x) => x.id == _id).firstOrNull;
    if (e == null) return const SizedBox(height: 120);
    final f = s.f;
    final hidden = s.data.hideValues;
    final cat = e.category;
    final card = s.card(e.cardId);
    final cur = f.current;
    final active = f.expenseActive(e, cur);
    final entryCycle = f.cycleOf(e.date);
    final cycle = e.isRecurring ? cur : entryCycle;
    final ended =
        e.isRecurring &&
        e.endDate != null &&
        f.cycleOf(e.endDate!).key < cur.key;
    final canEnd =
        e.isRecurring &&
        active &&
        (e.endDate == null || f.cycleOf(e.endDate!).key > cur.key);

    // Informações contextuais para o rodapé do detalhe:
    // - Recorrente com data final → progresso das parcelas até acabar
    // - Recorrente contínuo → custo anual + ciclos ativos
    // - Único com histórico do mesmo nome → quantidade e total acumulado
    final endCycle = (e.isRecurring && e.endDate != null)
        ? f.cycleOf(e.endDate!)
        : null;
    final totalInstallments = endCycle == null
        ? 0
        : (endCycle.key - entryCycle.key + 1).clamp(1, 999);
    final paidInstallments = endCycle == null
        ? 0
        : (cur.key - entryCycle.key + 1).clamp(0, totalInstallments);
    final remainingInstallments =
        (totalInstallments - paidInstallments).clamp(0, totalInstallments);
    final activeRecurringCycles = e.isRecurring
        ? (cur.key - entryCycle.key + 1).clamp(1, 999)
        : 0;
    final sameNameExpenses = e.isRecurring
        ? const <Expense>[]
        : s.data.expenses
              .where((x) => foldText(x.name) == foldText(e.name))
              .toList();
    final sameNameTotal = sameNameExpenses.fold<int>(0, (t, x) => t + x.cents);

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
        ? 'Todo mês, desde ${DateFormat("d 'de' MMM 'de' y", 'pt_BR').format(e.date)}'
        : _cap(DateFormat("EEE, d 'de' MMM 'de' y", 'pt_BR').format(e.date));
    final manageUrl = e.isRecurring ? subscriptionManageUrlFor(e.name) : null;

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
                  onTap: () => openEditExpense(
                    context,
                    e,
                    onSplit: (newId) {
                      if (mounted) setState(() => _id = newId);
                    },
                  ),
                ),
                if (manageUrl != null)
                  CircleAction(
                    icon: LucideIcons.externalLink,
                    label: 'Gerenciar',
                    size: canEnd ? 56 : 62,
                    onTap: () => _openManageUrl(context, manageUrl),
                  )
                else
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
                      toast(widget.host, 'Duplicado para hoje');
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
                      toast(widget.host, 'Não repete a partir do próximo ciclo');
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
            card?.isCard == true ? 'Cartão' : 'Conta',
            trailing: card == null
                ? _val(c, 'Sem conta')
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (card.isCard)
                        BrandBadge(brand: card.brand, bordered: true)
                      else
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(card.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          card.last4.isNotEmpty
                              ? '${card.name} ••${card.last4}'
                              : card.name,
                          style: T.bodyStrong.copyWith(color: c.text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
          _Row(
            'Tipo',
            trailing: _val(
              c,
              e.isRecurring
                  ? (e.endDate != null ? 'Parcelado / até data' : 'Recorrente')
                  : 'Único',
            ),
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

          // Bloco contextual relevante ao tipo do gasto
          if (endCycle != null) ...[
            const SizedBox(height: Space.base),
            Container(
              padding: const EdgeInsets.all(Space.base),
              decoration: ShapeDecoration(
                color: c.isDark ? c.cardAlt : c.surfaceLow,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Progresso até acabar',
                          style: T.small.copyWith(color: c.textSecondary),
                        ),
                      ),
                      Text(
                        '$paidInstallments de $totalInstallments',
                        style: T.bodyStrong.copyWith(color: c.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SpringBar(
                    fraction: paidInstallments / totalInstallments,
                    color: c.tone(cat.color),
                    track: c.isDark ? c.cardAlt : c.border,
                    height: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    remainingInstallments == 0
                        ? 'Último mês · Total ${fmtMoney(e.cents * totalInstallments, hidden: hidden)}'
                        : 'Faltam $remainingInstallments ${remainingInstallments == 1 ? 'mês' : 'meses'} · ${fmtMoney(e.cents * remainingInstallments, hidden: hidden)} restante',
                    style: T.small.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ] else if (e.isRecurring) ...[
            const SizedBox(height: Space.base),
            Container(
              padding: const EdgeInsets.all(Space.base),
              decoration: ShapeDecoration(
                color: c.isDark ? c.cardAlt : c.surfaceLow,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custo anual',
                          style: T.small.copyWith(color: c.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        MoneyText(
                          e.cents * 12,
                          hidden: hidden,
                          style: T.headline,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Ativo há',
                        style: T.small.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$activeRecurringCycles ${activeRecurringCycles == 1 ? 'mês' : 'meses'}',
                        style: T.bodyStrong.copyWith(color: c.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else if (sameNameExpenses.length > 1) ...[
            const SizedBox(height: Space.base),
            Container(
              padding: const EdgeInsets.all(Space.base),
              decoration: ShapeDecoration(
                color: c.isDark ? c.cardAlt : c.surfaceLow,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Histórico de ${e.name}',
                          style: T.small.copyWith(color: c.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sameNameExpenses.length} lançamentos registrados',
                          style: T.bodyMedium.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  MoneyText(
                    sameNameTotal,
                    hidden: hidden,
                    style: T.bodyStrong,
                  ),
                ],
              ),
            ),
          ],
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
    if (widget.host.mounted) {
      toast(widget.host, 'Gasto excluído', icon: LucideIcons.trash2);
    }
  }

  static const _linksChannel = MethodChannel('com.mare.mare/links');

  Future<void> _openManageUrl(BuildContext context, String url) async {
    try {
      final ok =
          await _linksChannel.invokeMethod<bool>('openUrl', {'url': url}) ??
          false;
      if (!ok && context.mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) toast(context, 'Link copiado');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) toast(context, 'Link copiado');
    }
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
