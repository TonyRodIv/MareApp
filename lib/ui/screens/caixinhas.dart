import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/finance.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/validation.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'add_expense.dart' show pickDate;
import 'box_form.dart';
import 'shell.dart';

/// Caixinhas redesenhada do zero:
/// Hero centralizado com emblema e total acumulado, filtro Ativas/Encerradas
/// e cards modernos com anel circular de progresso ao redor do ícone.
class CaixinhasScreen extends StatefulWidget {
  final bool standalone;
  const CaixinhasScreen({super.key, this.standalone = false});
  @override
  State<CaixinhasScreen> createState() => _CaixinhasScreenState();
}

class _CaixinhasScreenState extends State<CaixinhasScreen> {
  bool _showClosed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final open = f.openBoxes;
    final closed = s.data.boxes.where((b) => b.closedKey != null).toList();
    final list = _showClosed ? closed : open;
    final hidden = s.data.hideValues;
    final total = f.boxesBalanceTotal();
    final totalGoals = open.fold<int>(0, (t, b) => t + (b.goalCents ?? 0));
    final monthly = open.fold<int>(
      0,
      (t, b) => t + f.contributionFor(b, f.current),
    );
    final pad = sidePadding(context, maxWidth: 720);

    final scroll = CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        PinnedCupertinoBar(
          height: 60,
          maxWidth: 720,
          builder: (ctx, progress) => Row(
            children: [
              if (widget.standalone) ...[
                const BackChevron(),
                Expanded(child: BarTitle('Caixinhas', progress: progress)),
              ] else
                Expanded(
                  child: Text(
                    'Caixinhas',
                    style: T.pageTitle.copyWith(color: c.text),
                  ),
                ),
              Builder(
                builder: (_) {
                  final (btnBg, btnFg) = softActionTone(
                    c.palette.primary[500],
                    isDark: c.isDark,
                  );
                  return RoundIconButton(
                    LucideIcons.plus,
                    size: 44,
                    label: 'Nova caixinha',
                    bg: btnBg,
                    fg: btnFg,
                    onTap: () => pushFluid(context, const BoxForm()),
                  );
                },
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            pad,
            widget.standalone ? Space.sm : Space.lg,
            pad,
            widget.standalone
                ? Space.xl + MediaQuery.paddingOf(context).bottom
                : navClearance(context),
          ),
          sliver: SliverList.list(
            children: [
              if (widget.standalone) ...[
                LargeTitle('Caixinhas', style: T.pageTitle),
                const SizedBox(height: Space.lg),
              ],
              // ── Hero centralizado (evita duplicar ícone quando a lista está vazia)
                  if (open.isNotEmpty) ...[
                    Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: c.primarySoft,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: c.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            LucideIcons.piggyBank,
                            size: 28,
                            color: c.primary,
                          ),
                        ),
                        const SizedBox(height: Space.base),
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
                          totalGoals > 0
                              ? 'de ${fmtMoney(totalGoals, hidden: hidden)} em metas'
                              : '+${fmtMoney(monthly, hidden: hidden)} por mês',
                          textAlign: TextAlign.center,
                          style: T.label.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                  ],

                  if (closed.isNotEmpty) ...[
                    Segmented<bool>(
                      value: _showClosed,
                      options: const {
                        false: 'Ativas',
                        true: 'Encerradas',
                      },
                      onChanged: (v) => setState(() => _showClosed = v),
                    ),
                    const SizedBox(height: Space.md),
                  ],

                  if (list.isEmpty)
                    EmptyState(
                      icon: LucideIcons.piggyBank,
                      title: _showClosed
                          ? 'Nenhuma caixinha encerrada'
                          : 'Nenhuma caixinha ainda',
                      message: _showClosed
                          ? 'Quando você encerrar uma caixinha, ela aparece aqui.'
                          : 'Guarde um valor todo mês para metas ou reservas.',
                      action: _showClosed ? null : 'Criar caixinha',
                      onAction: () => pushFluid(context, const BoxForm()),
                    )
                  else
                    ListGroup(
                      children: [
                        for (final box in list)
                          _BoxRow(box: box, f: f, hidden: hidden),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );

    final body = Stack(
      children: [
        const GlowBackground(height: 440),
        widget.standalone ? CollapsingTitleScope(child: scroll) : scroll,
      ],
    );
    if (!widget.standalone) return body;
    return SheetScaler(
      child: CupertinoPageScaffold(backgroundColor: c.bg, child: body),
    );
  }
}

/// Linha de caixinha no novo padrão agrupado, com anel circular de progresso de 40px.
class _BoxRow extends StatelessWidget {
  final Caixinha box;
  final Finance f;
  final bool hidden;
  const _BoxRow({required this.box, required this.f, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bal = f.boxBalance(box);
    final per = f.contributionFor(box, f.current);
    final goal = box.goalCents;
    final hasGoal = goal != null && goal > 0;
    final pct = hasGoal ? (bal / goal).clamp(0.0, 1.0) : 0.35;
    final accent = c.tone(box.colorValue);

    return ListRow(
      leading: ProgressRing(
        size: 40,
        stroke: 3,
        fraction: pct,
        color: accent,
        track: c.cardAlt,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: box.colorValue.withValues(alpha: c.isDark ? 0.22 : 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(box.iconData, size: 16, color: accent),
        ),
      ),
      title: box.name,
      subtitle: hasGoal
          ? '${(bal / goal * 100).clamp(0, 999).round()}% de ${fmtMoney(goal, hidden: hidden)}'
          : '+${fmtMoney(per, hidden: hidden)}/mês',
      value: fmtMoney(bal, hidden: hidden),
      arrow: true,
      onTap: () => push(context, BoxDetail(id: box.id)),
    );
  }
}

/// Detalhe da caixinha redesenhado: anel circular grande centralizado no topo,
/// ações em pílulas limpas e lista espaçada de movimentações.
class BoxDetail extends StatelessWidget {
  final String id;
  const BoxDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final box = s.box(id);
    if (box == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: const SizedBox(),
      );
    }
    final f = s.f;
    final hidden = s.data.hideValues;
    final bal = f.boxBalance(box);
    final plan = box.currentPlan;
    final per = f.contributionFor(box, f.current);
    final eta = f.cyclesToGoal(box);
    final goal = box.goalCents;
    final hasGoal = goal != null && goal > 0;
    final fraction = hasGoal ? (bal / goal).clamp(0.0, 1.0) : 1.0;
    final moves = [...box.movements]..sort((a, b) => b.date.compareTo(a.date));
    final pad = sidePadding(context, maxWidth: 680);

    return SheetScaler(
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: Stack(
        children: [
          GlowBackground(
            tint: context.c.tone(box.colorValue, min: 2.5),
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
                        box.name,
                        style: T.bodyStrong.copyWith(color: c.text),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    RoundIconButton(
                      LucideIcons.ellipsis,
                      size: 44,
                      label: 'Mais opções',
                      glass: true,
                      onTap: () => _more(context, box, bal),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pad,
                  Space.lg,
                  pad,
                  Space.xl + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.list(
                  children: [
                    // ── Hero circular centralizado (inspirado na tela central de Savings)
                    Column(
                      children: [
                        SpringBuilder(
                          value: hasGoal ? fraction : 0.72,
                          from: 0,
                          spring: Springs.settle,
                          builder: (_, v, _) => ProgressRing(
                            size: 136,
                            stroke: 8,
                            fraction: v,
                            color: c.tone(box.colorValue),
                            track: c.cardAlt,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: box.colorValue.withValues(
                                  alpha: c.isDark ? 0.18 : 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                box.iconData,
                                size: 42,
                                color: c.tone(box.colorValue),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.lg),
                        CountingMoney(
                          cents: bal,
                          builder: (v) => MoneyText(
                            v,
                            hidden: hidden,
                            style: T.displayLg,
                            color: bal < 0 ? c.negative : null,
                          ),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          hasGoal
                              ? bal >= goal
                                    ? 'Meta de ${fmtMoney(goal, hidden: hidden)} alcançada!'
                                    : 'de ${fmtMoney(goal, hidden: hidden)}${eta != null ? ' · ~$eta ${eta == 1 ? 'mês' : 'meses'}' : ''}'
                              : plan.mode == PlanMode.percent
                              ? '${(plan.amount / 100).toStringAsFixed(plan.amount % 100 == 0 ? 0 : 1)}% do salário · ${fmtMoney(per, hidden: hidden)}/mês'
                              : '+${fmtMoney(per, hidden: hidden)} por mês',
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
                          icon: LucideIcons.arrowDownToLine,
                          label: 'Guardar',
                          onTap: () {
                            if (!box.isOpen) {
                              toast(
                                context,
                                'Esta caixinha já foi encerrada',
                                icon: LucideIcons.triangleAlert,
                              );
                              return;
                            }
                            editMovement(
                              context,
                              box.id,
                              MovementType.deposit,
                            );
                          },
                        ),
                        CircleAction(
                          icon: LucideIcons.shoppingCart,
                          label: 'Usar',
                          onTap: () {
                            if (!box.isOpen) {
                              toast(
                                context,
                                'Esta caixinha já foi encerrada',
                                icon: LucideIcons.triangleAlert,
                              );
                              return;
                            }
                            if (bal <= 0) {
                              toast(
                                context,
                                'Sem saldo disponível nesta caixinha',
                                icon: LucideIcons.triangleAlert,
                              );
                              return;
                            }
                            editMovement(
                              context,
                              box.id,
                              MovementType.spend,
                            );
                          },
                        ),
                        CircleAction(
                          icon: LucideIcons.arrowUpFromLine,
                          label: 'Resgatar',
                          onTap: () {
                            if (!box.isOpen) {
                              toast(
                                context,
                                'Esta caixinha já foi encerrada',
                                icon: LucideIcons.triangleAlert,
                              );
                              return;
                            }
                            if (bal <= 0) {
                              toast(
                                context,
                                'Sem saldo disponível para resgatar',
                                icon: LucideIcons.triangleAlert,
                              );
                              return;
                            }
                            editMovement(
                              context,
                              box.id,
                              MovementType.redeem,
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: Space.lg),
                    if (moves.isEmpty)
                      EmptyState(
                        icon: LucideIcons.arrowLeftRight,
                        title: 'Sem movimentações extras',
                        message:
                            'Guarde um extra, registre um pagamento com esta reserva ou resgate para o saldo livre.',
                      )
                    else
                      ListGroup(
                        children: [
                          for (final m in moves)
                            _MoveRow(box: box, m: m, hidden: hidden),
                        ],
                      ),
                    const SizedBox(height: Space.base),
                    Text(
                      'Aporte automático ativo desde ${f.fromKey(box.createdKey).label()}.',
                      textAlign: TextAlign.center,
                      style: T.small.copyWith(color: c.textTertiary),
                    ),
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

  Future<void> _more(BuildContext context, Caixinha box, Cents bal) async {
    final s = context.storeRead;
    final a = await actionSheet<String>(
      context,
      title: box.name,
      actions: [
        if (box.isOpen)
          const SheetAction(
            'Editar caixinha',
            'edit',
            icon: LucideIcons.pencil,
          ),
        if (box.isOpen)
          SheetAction(
            bal > 0 ? 'Encerrar e devolver saldo' : 'Encerrar caixinha',
            'close',
            icon: LucideIcons.archive,
          ),
        const SheetAction(
          'Excluir caixinha',
          'delete',
          destructive: true,
          icon: LucideIcons.trash2,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (a) {
      case 'edit':
        openEditBox(context, box);
      case 'close':
        final ok = await confirm(
          context,
          title: 'Encerrar "${box.name}"?',
          message:
              '${fmtMoney(bal)} voltam para o saldo livre deste ciclo e a caixinha para de receber aportes.',
          action: 'Encerrar',
          destructive: false,
        );
        if (ok && context.mounted) {
          s.closeBox(box.id);
          Navigator.pop(context);
          toast(context, 'Caixinha encerrada');
        }
      case 'delete':
        final ok = await confirm(
          context,
          title: 'Excluir "${box.name}"?',
          message:
              'Apaga a caixinha e todo o histórico dela. Para devolver o saldo, use "Encerrar".',
          action: 'Excluir',
        );
        if (ok && context.mounted) {
          s.deleteBox(box.id);
          Navigator.pop(context);
          toast(context, 'Caixinha excluída', icon: LucideIcons.trash2);
        }
    }
  }
}

class _MoveRow extends StatelessWidget {
  final Caixinha box;
  final Movement m;
  final bool hidden;
  const _MoveRow({required this.box, required this.m, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (icon, label) = switch (m.type) {
      MovementType.deposit => (LucideIcons.arrowDownToLine, 'Guardado'),
      MovementType.spend => (LucideIcons.shoppingCart, 'Usado'),
      MovementType.redeem => (LucideIcons.arrowUpFromLine, 'Resgatado'),
    };
    final when = m.recurrence == Recurrence.monthly
        ? 'Todo ciclo${m.endDate != null ? ' até ${DateFormat('MM/yy').format(m.endDate!)}' : ''}'
        : DateFormat('dd/MM/yyyy').format(m.date);
    return ListRow(
      leading: IconBadge(icon, box.colorValue, size: 40),
      title: m.name,
      subtitle: '$label · $when',
      value: '${m.sign > 0 ? '+' : '−'}${fmtMoney(m.cents, hidden: hidden)}',
      valueColor: m.sign > 0 ? c.positive : null,
      onTap: () => showMovementActions(context, box, m),
    );
  }
}

/// Detalhe de uma movimentação da caixinha em bottom sheet (mesmo padrão do gasto).
Future<void> showMovementActions(
  BuildContext context,
  Caixinha box,
  Movement m,
) => showIosSheet<void>(
  context,
  builder: (_) => MovementSheet(boxId: box.id, movementId: m.id, host: context),
);

class MovementSheet extends StatelessWidget {
  final String boxId;
  final String movementId;
  final BuildContext host;
  const MovementSheet({
    super.key,
    required this.boxId,
    required this.movementId,
    required this.host,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final box = s.box(boxId);
    final m = box?.movements.where((x) => x.id == movementId).firstOrNull;
    if (box == null || m == null) return const SizedBox(height: 120);
    final f = s.f;
    final hidden = s.data.hideValues;
    final cur = f.current;
    final isRecurring = m.recurrence == Recurrence.monthly;
    final active = f.movementActive(m, cur);
    final entryCycle = f.cycleOf(m.date);
    final cycle = isRecurring ? cur : entryCycle;
    final ended =
        isRecurring &&
        m.endDate != null &&
        f.cycleOf(m.endDate!).key < cur.key;
    final canEnd =
        isRecurring &&
        active &&
        (m.endDate == null || f.cycleOf(m.endDate!).key > cur.key);

    final (icon, typeLabel) = switch (m.type) {
      MovementType.deposit => (LucideIcons.arrowDownToLine, 'Guardado'),
      MovementType.spend => (LucideIcons.shoppingCart, 'Usado'),
      MovementType.redeem => (LucideIcons.arrowUpFromLine, 'Resgatado'),
    };
    final badgeColor = box.colorValue;

    final status = isRecurring
        ? (ended
              ? 'Encerrado'
              : (m.endDate == null
                    ? 'Ativo'
                    : 'Ativo até ${DateFormat('MM/yy').format(m.endDate!)}'))
        : (entryCycle.key == cur.key
              ? 'Neste ciclo'
              : (entryCycle.key < cur.key ? 'Ciclo anterior' : 'Ciclo futuro'));
    final dateLabel = isRecurring
        ? 'Todo ciclo, desde ${DateFormat("d 'de' MMM 'de' y", 'pt_BR').format(m.date)}'
        : _cap(DateFormat("EEE, d 'de' MMM 'de' y", 'pt_BR').format(m.date));

    final bal = f.boxBalance(box);
    final baseRef = math.max(bal + (m.sign < 0 ? m.cents : 0), m.cents);
    final share = baseRef > 0 ? (m.cents / baseRef).clamp(0.0, 1.0) : 0.0;

    void close() => Navigator.of(context).pop();

    return SheetBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho igual ao ExpenseSheet (fechar acima à direita; ícone+nome abaixo)
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
                        IconBadge(icon, badgeColor, size: 52),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.name,
                                style: T.headline.copyWith(color: c.text),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$typeLabel · ${box.name}',
                                style: T.label.copyWith(color: c.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

          // Valor e data (sem sinal de menos na frente, como no ExpenseSheet)
          Reveal(
            blur: false,
            index: 1,
            baseDelay: Duration.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MoneyText(
                  m.cents.abs(),
                  hidden: hidden,
                  style: T.displayLg,
                  color: m.sign > 0 ? c.positive : null,
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

          // Ações rápidas circulares (somente para caixinhas abertas)
          if (box.isOpen) ...[
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
                      editMovement(host, box.id, m.type, existing: m);
                    },
                  ),
                  CircleAction(
                    icon: LucideIcons.copy,
                    label: 'Duplicar',
                    size: canEnd ? 56 : 62,
                    onTap: () {
                      final err = s.addMovement(
                        box.id,
                        Movement(
                          name: m.name,
                          cents: m.cents,
                          type: m.type,
                          date: DateTime.now(),
                        ),
                      );
                      close();
                      if (!host.mounted) return;
                      if (err != null) {
                        toast(host, err, icon: LucideIcons.triangleAlert);
                      } else {
                        toast(host, 'Duplicado para hoje');
                      }
                    },
                  ),
                  if (canEnd)
                    CircleAction(
                      icon: LucideIcons.calendarOff,
                      label: 'Encerrar',
                      size: 56,
                      onTap: () {
                        s.endMovement(box.id, m.id);
                        close();
                        toast(host, 'Não repete a partir do próximo ciclo');
                      },
                    ),
                  CircleAction(
                    icon: LucideIcons.trash2,
                    label: 'Excluir',
                    danger: true,
                    size: canEnd ? 56 : 62,
                    onTap: () => _delete(context, box, m, close),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Detalhes
          Text('Detalhes', style: T.headline.copyWith(color: c.text)),
          const SizedBox(height: 6),
          _MoveDetailRow('Caixinha', box.name),
          _MoveDetailRow('Movimentação', typeLabel),
          _MoveDetailRow('Tipo', isRecurring ? 'Recorrente' : 'Único'),
          _MoveDetailRow('Ciclo', cycle.label()),
          if (isRecurring)
            _MoveDetailRow(
              'Término',
              m.endDate == null
                  ? 'Sem data final'
                  : DateFormat('dd/MM/yyyy').format(m.endDate!),
            ),
          _MoveDetailRow(
            'Situação',
            status,
            valueColor: ended ? c.textSecondary : c.positive,
          ),
          const SizedBox(height: 18),

          // Impacto na caixinha (borderless, mesmo padrão do detalhe de gasto)
          Container(
            padding: const EdgeInsets.all(Space.base),
            decoration: ShapeDecoration(
              color: c.isDark ? c.bg : c.surfaceLow,
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
                        'Impacto em ${box.name}',
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
                  color: c.tone(box.colorValue),
                  track: c.isDark ? c.cardAlt : c.border,
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

  Future<void> _delete(
    BuildContext context,
    Caixinha box,
    Movement m,
    VoidCallback close,
  ) async {
    final s = context.storeRead;
    final ok = await confirm(
      context,
      title: 'Excluir "${m.name}"?',
      message: m.recurrence == Recurrence.monthly
          ? 'Some de todos os ciclos desta caixinha. Para manter o histórico, use Encerrar.'
          : null,
      action: 'Excluir',
    );
    if (!ok) return;
    final err = s.deleteMovement(box.id, m.id);
    if (err != null) {
      if (context.mounted) toast(context, err, icon: LucideIcons.triangleAlert);
      return;
    }
    close();
    if (host.mounted) {
      toast(host, 'Movimentação excluída', icon: LucideIcons.trash2);
    }
  }
}

class _MoveDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _MoveDetailRow(this.label, this.value, {this.valueColor});

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
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: T.bodyStrong.copyWith(color: valueColor ?? c.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Abre a tela de criar/editar movimentação (mesmo estilo da tela de editar gasto).
Future<void> editMovement(
  BuildContext context,
  String boxId,
  MovementType type, {
  Movement? existing,
}) {
  return push<void>(
    context,
    MovementForm(boxId: boxId, type: type, existing: existing),
  );
}

class MovementForm extends StatefulWidget {
  final String boxId;
  final MovementType type;
  final Movement? existing;
  const MovementForm({
    super.key,
    required this.boxId,
    required this.type,
    this.existing,
  });
  @override
  State<MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<MovementForm> {
  late final _amount = AmountController(widget.existing?.cents ?? 0);
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late Recurrence _rec = widget.existing?.recurrence ?? Recurrence.once;
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late DateTime? _end = widget.existing?.endDate;
  late bool _typing = widget.existing == null;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    super.dispose();
  }

  (String, String, String) get _copy => switch (widget.type) {
    MovementType.deposit => (
      'Guardar um extra',
      'Sai do saldo livre do ciclo e entra na caixinha.',
      'Ex.: 13º, sobra do mês',
    ),
    MovementType.spend => (
      'Usar a caixinha',
      'Pago com esta reserva. Não mexe no saldo livre.',
      'Ex.: passagem, conserto',
    ),
    MovementType.redeem => (
      'Resgatar para o saldo',
      'Sai da caixinha e volta para o saldo livre.',
      'Ex.: reforço do mês',
    ),
  };

  Movement _buildDraft() {
    final name = _name.text.trim().isEmpty
        ? switch (widget.type) {
            MovementType.deposit => 'Extra',
            MovementType.spend => 'Gasto',
            MovementType.redeem => 'Resgate',
          }
        : _name.text.trim();
    return Movement(
      id: widget.existing?.id,
      name: name,
      cents: _amount.value,
      type: widget.type,
      date: _date,
      recurrence: widget.type == MovementType.spend ? _rec : Recurrence.once,
      endDate: widget.type == MovementType.spend && _rec == Recurrence.monthly
          ? _end
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final box = s.box(widget.boxId);
    final (newTitle, hint, ph) = _copy;
    final pageTitle = widget.existing == null
        ? newTitle
        : 'Editar movimentação';
    final df = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');
    final avail = box == null
        ? 0
        : availableBoxBalance(
            f,
            box,
            excludingMovementId: widget.existing?.id,
          );
    final draft = _buildDraft();
    final validationError = _amount.value > 0
        ? validateMovement(
            f,
            box,
            draft,
            replacingId: widget.existing?.id,
          )
        : null;
    final valid = _amount.value > 0 && validationError == null;
    final pad = sidePadding(context);

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: Column(
        children: [
          Expanded(
            child: CollapsingTitleScope(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  PinnedCupertinoBar(
                    height: 60,
                    builder: (ctx, progress) => Row(
                      children: [
                        const BackChevron(),
                        Expanded(
                          child: BarTitle(pageTitle, progress: progress),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.lg),
                    sliver: SliverList.list(
                      children: [
                        LargeTitle(pageTitle, style: T.display),
                      const SizedBox(height: Space.xs),
                      Text(
                        widget.type == MovementType.deposit
                            ? hint
                            : '$hint Disponível: ${fmtMoney(avail, hidden: s.data.hideValues)}.',
                        style: T.label.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Pressable(
                        onTap: () => setState(() => _typing = !_typing),
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: c.border)),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AmountDisplay(
                              cents: _amount.value,
                              size: 40,
                              color: validationError != null
                                  ? c.negative
                                  : c.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      QuickAddChips(controller: _amount, center: false),
                      if (validationError != null) ...[
                        const SizedBox(height: Space.md),
                        Container(
                          padding: const EdgeInsets.all(Space.md),
                          decoration: ShapeDecoration(
                            color: c.negativeSoft,
                            shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(
                                Space.radiusMd,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.triangleAlert,
                                size: 18,
                                color: c.negative,
                              ),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Text(
                                  validationError,
                                  style: T.small.copyWith(color: c.negative),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: easeOutExpo,
                        child: _typing
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Keypad(controller: _amount),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 18),
                      const FieldLabel('Nome'),
                      AppField(
                        controller: _name,
                        placeholder: ph,
                        maxLength: 40,
                      ),
                      if (widget.type == MovementType.spend) ...[
                        const SizedBox(height: 18),
                        const FieldLabel('Frequência'),
                        Segmented<Recurrence>(
                          value: _rec,
                          options: const {
                            Recurrence.once: 'Uma vez',
                            Recurrence.monthly: 'Todo ciclo',
                          },
                          onChanged: (r) => setState(() {
                            _rec = r;
                            if (r != Recurrence.monthly) _end = null;
                          }),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _rec == Recurrence.monthly
                              ? 'Repete todo ciclo descontando desta caixinha até encerrar.'
                              : 'Desconta apenas uma vez desta caixinha.',
                          style: T.small.copyWith(color: c.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FieldLabel(
                        widget.type == MovementType.spend &&
                                _rec == Recurrence.monthly
                            ? 'Começa em'
                            : 'Data',
                      ),
                      SelectField(
                        leading: Icon(
                          LucideIcons.calendar,
                          size: 18,
                          color: c.textSecondary,
                        ),
                        value: df.format(_date),
                        placeholder: '',
                        onTap: () => pickDate(
                          context,
                          _date,
                          (d) => setState(() {
                            _date = d;
                            if (_end != null &&
                                dateOnly(_end!).isBefore(dateOnly(d))) {
                              _end = d;
                            }
                          }),
                        ),
                      ),
                      if (widget.type == MovementType.spend &&
                          _rec == Recurrence.monthly) ...[
                        const SizedBox(height: 14),
                        const FieldLabel('Termina em (opcional)'),
                        SelectField(
                          leading: Icon(
                            LucideIcons.calendarX,
                            size: 18,
                            color: c.textSecondary,
                          ),
                          value: _end == null ? null : df.format(_end!),
                          placeholder: 'Sem data final',
                          onTap: () => pickDate(
                            context,
                            _end ?? _date,
                            (d) => setState(() => _end = d),
                            onClear: () => setState(() => _end = null),
                            min: _date,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
              child: PillButton(
                widget.existing == null
                    ? switch (widget.type) {
                        MovementType.deposit => 'Guardar valor',
                        MovementType.spend => 'Registrar uso',
                        MovementType.redeem => 'Resgatar valor',
                      }
                    : 'Salvar alterações',
                onTap: valid ? _save : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final s = context.storeRead;
    final m = _buildDraft();
    final err = widget.existing == null
        ? s.addMovement(widget.boxId, m)
        : s.updateMovement(widget.boxId, m);
    if (err != null) {
      toast(context, err, icon: LucideIcons.triangleAlert);
      return;
    }
    Navigator.pop(context);
    toast(context, 'Movimentação salva');
  }
}
