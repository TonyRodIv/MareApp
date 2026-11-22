import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/finance.dart';
import '../../data/models.dart';
import '../../data/store.dart';
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
  const CaixinhasScreen({super.key});
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

    return Stack(
      children: [
        GlowBackground(tint: c.primary, height: 460),
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            PinnedCupertinoBar(
              height: 60,
              maxWidth: 720,
              builder: (ctx, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      'Caixinhas',
                      style: T.title.copyWith(color: c.text, fontSize: 26),
                    ),
                  ),
                  RoundIconButton(
                    LucideIcons.plus,
                    size: 44,
                    label: 'Nova caixinha',
                    bg: c.primary,
                    fg: c.onPrimary,
                    onTap: () => pushFluid(context, const BoxForm()),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                pad,
                Space.lg,
                pad,
                navClearance(context),
              ),
              sliver: SliverList.list(
                children: [
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
                            style: T.display.copyWith(fontSize: 36),
                          ),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          totalGoals > 0
                              ? 'de ${fmtMoney(totalGoals, hidden: hidden)} em metas · +${fmtMoney(monthly, hidden: hidden)}/ciclo'
                              : '+${fmtMoney(monthly, hidden: hidden)} entram por ciclo',
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
                      options: {
                        false: 'Ativas (${open.length})',
                        true: 'Encerradas (${closed.length})',
                      },
                      onChanged: (v) => setState(() => _showClosed = v),
                    ),
                    const SizedBox(height: Space.base),
                  ],

                  if (list.isEmpty)
                    EmptyState(
                      icon: LucideIcons.piggyBank,
                      title: _showClosed
                          ? 'Nenhuma caixinha encerrada'
                          : 'Nenhuma caixinha ainda',
                      message: _showClosed
                          ? 'Quando você encerrar uma caixinha, ela aparece aqui.'
                          : 'Uma caixinha recebe um valor fixo ou % do salário todo ciclo e acumula automaticamente.',
                      action: _showClosed ? null : 'Criar caixinha',
                      onAction: () => pushFluid(context, const BoxForm()),
                    )
                  else
                    Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const SizedBox(height: Space.sm),
                          _BoxCard(box: list[i], f: f, hidden: hidden),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Card horizontal moderno com anel circular de progresso ao redor do ícone.
class _BoxCard extends StatelessWidget {
  final Caixinha box;
  final Finance f;
  final bool hidden;
  const _BoxCard({required this.box, required this.f, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bal = f.boxBalance(box);
    final per = f.contributionFor(box, f.current);
    final goal = box.goalCents;
    final hasGoal = goal != null && goal > 0;
    final pct = hasGoal ? (bal / goal).clamp(0.0, 1.0) : 1.0;

    return Pressable(
      scale: 0.985,
      onTap: () => push(context, BoxDetail(id: box.id)),
      child: Container(
        padding: const EdgeInsets.all(Space.base),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: c.border.withValues(alpha: c.isDark ? 0.5 : 0.7),
          ),
        ),
        child: Row(
          children: [
            _ProgressRing(
              size: 52,
              stroke: 4,
              fraction: hasGoal ? pct : 0.35,
              color: c.tone(box.colorValue),
              track: c.cardAlt,
              child: Icon(
                box.iconData,
                size: 22,
                color: c.tone(box.colorValue),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    box.name,
                    style: T.bodyStrong.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    hasGoal
                        ? '${fmtMoney(bal, hidden: hidden)} de ${fmtMoney(goal, hidden: hidden)}'
                        : '+${fmtMoney(per, hidden: hidden)} por ciclo',
                    style: T.small.copyWith(color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasGoal)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.sm,
                      vertical: Space.xs,
                    ),
                    decoration: BoxDecoration(
                      color: box.colorValue.withValues(
                        alpha: c.isDark ? 0.22 : 0.14,
                      ),
                      borderRadius: BorderRadius.circular(Space.radiusSm),
                    ),
                    child: Text(
                      '${(bal / goal * 100).clamp(0, 999).round()}%',
                      style: T.smallStrong.copyWith(
                        color: c.tone(box.colorValue, min: 4.5),
                      ),
                    ),
                  )
                else
                  Text(
                    fmtMoney(bal, hidden: hidden),
                    style: T.bodyStrong.copyWith(color: c.text),
                  ),
              ],
            ),
            const SizedBox(width: Space.xs),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textTertiary),
          ],
        ),
      ),
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
    if (box == null)
      return CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: const SizedBox(),
      );
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

    return CupertinoPageScaffold(
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
                      bg: c.card.withValues(alpha: 0.78),
                      onTap: () => _more(context, box, bal),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, Space.lg, pad, Space.xl),
                sliver: SliverList.list(
                  children: [
                    // ── Hero circular centralizado (inspirado na tela central de Savings)
                    Column(
                      children: [
                        SpringBuilder(
                          value: hasGoal ? fraction : 0.72,
                          from: 0,
                          spring: Springs.settle,
                          builder: (_, v, _) => _ProgressRing(
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
                            style: T.display.copyWith(fontSize: 36),
                            color: bal < 0 ? c.negative : null,
                          ),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          hasGoal
                              ? bal >= goal
                                    ? 'Meta de ${fmtMoney(goal, hidden: hidden)} alcançada!'
                                    : 'de ${fmtMoney(goal, hidden: hidden)}${eta != null ? ' · ~$eta ${eta == 1 ? 'ciclo' : 'ciclos'}' : ''}'
                              : plan.mode == PlanMode.percent
                              ? '${(plan.amount / 100).toStringAsFixed(plan.amount % 100 == 0 ? 0 : 1)}% do salário · ${fmtMoney(per, hidden: hidden)}/ciclo'
                              : '+${fmtMoney(per, hidden: hidden)} por ciclo',
                          textAlign: TextAlign.center,
                          style: T.label.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),

                    // ── Ações rápidas em pílulas limpas
                    Row(
                      children: [
                        Expanded(
                          child: PillButton(
                            'Guardar',
                            icon: LucideIcons.arrowDownToLine,
                            height: 48,
                            onTap: () => editMovement(
                              context,
                              box.id,
                              MovementType.deposit,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: PillButton(
                            'Usar',
                            icon: LucideIcons.shoppingCart,
                            kind: BtnKind.ghost,
                            height: 48,
                            onTap: () => editMovement(
                              context,
                              box.id,
                              MovementType.spend,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: PillButton(
                            'Resgatar',
                            icon: LucideIcons.arrowUpFromLine,
                            kind: BtnKind.ghost,
                            height: 48,
                            onTap: () => editMovement(
                              context,
                              box.id,
                              MovementType.redeem,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SectionHeader('Movimentações'),
                    if (moves.isEmpty)
                      EmptyState(
                        icon: LucideIcons.arrowLeftRight,
                        title: 'Sem movimentações extras',
                        message:
                            'Guarde um extra, registre um pagamento com esta reserva ou resgate para o saldo livre.',
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < moves.length; i++) ...[
                            if (i > 0) const SizedBox(height: Space.xs),
                            Container(
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(i == 0 ? 22 : 8),
                                  bottom: Radius.circular(
                                    i == moves.length - 1 ? 22 : 8,
                                  ),
                                ),
                                border: Border.all(
                                  color: c.border.withValues(
                                    alpha: c.isDark ? 0.45 : 0.65,
                                  ),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _MoveRow(
                                box: box,
                                m: moves[i],
                                hidden: hidden,
                              ),
                            ),
                          ],
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
    );
  }

  Future<void> _more(BuildContext context, Caixinha box, Cents bal) async {
    final s = context.storeRead;
    final a = await actionSheet<String>(
      context,
      title: box.name,
      actions: [
        const SheetAction('Editar caixinha', 'edit', icon: LucideIcons.pencil),
        if (bal > 0 && box.closedKey == null)
          const SheetAction(
            'Encerrar e devolver saldo',
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
        pushFluid(context, BoxForm(box: box));
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

/// Anel circular de progresso reutilizado nos cards e no detalhe da caixinha.
class _ProgressRing extends StatelessWidget {
  final double size;
  final double stroke;
  final double fraction;
  final Color color;
  final Color track;
  final Widget child;
  const _ProgressRing({
    required this.size,
    required this.stroke,
    required this.fraction,
    required this.color,
    required this.track,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: fraction.clamp(0.0, 1.0),
          color: color,
          track: track,
          stroke: stroke,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;
  final double stroke;
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (fraction > 0) {
      final progPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        progPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

class _MoveRow extends StatelessWidget {
  final Caixinha box;
  final Movement m;
  final bool hidden;
  const _MoveRow({required this.box, required this.m, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (icon, label, color) = switch (m.type) {
      MovementType.deposit => (
        LucideIcons.arrowDownToLine,
        'Guardado',
        c.positive,
      ),
      MovementType.spend => (LucideIcons.shoppingCart, 'Usado', c.negative),
      MovementType.redeem => (
        LucideIcons.arrowUpFromLine,
        'Resgatado',
        c.accentWarm,
      ),
    };
    final when = m.recurrence == Recurrence.monthly
        ? 'Todo ciclo${m.endDate != null ? ' até ${DateFormat('MM/yy').format(m.endDate!)}' : ''}'
        : DateFormat('dd/MM/yyyy').format(m.date);
    return Pressable(
      scale: 0.985,
      onTap: () => editMovement(context, box.id, m.type, existing: m),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.base,
          vertical: Space.md,
        ),
        child: Row(
          children: [
            IconBadge(icon, color, size: 42),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: T.bodyStrong.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    '$label · $when',
                    style: T.small.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.sm),
            Text(
              '${m.sign > 0 ? '+' : '−'}${fmtMoney(m.cents, hidden: hidden)}',
              style: T.bodyStrong.copyWith(
                color: m.sign > 0 ? c.positive : c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet flutuante moderno para guardar / usar / resgatar (ou editar uma movimentação).
Future<void> editMovement(
  BuildContext context,
  String boxId,
  MovementType type, {
  Movement? existing,
}) {
  return showSheet(
    context,
    builder: (_) => _MovementForm(boxId: boxId, type: type, existing: existing),
  );
}

class _MovementForm extends StatefulWidget {
  final String boxId;
  final MovementType type;
  final Movement? existing;
  const _MovementForm({required this.boxId, required this.type, this.existing});
  @override
  State<_MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<_MovementForm> {
  late final _amount = AmountController(widget.existing?.cents ?? 0);
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late Recurrence _rec = widget.existing?.recurrence ?? Recurrence.once;
  late DateTime _date = widget.existing?.date ?? DateTime.now();

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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (title, hint, ph) = _copy;
    final valid = _amount.value > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? title : 'Editar movimentação',
            style: T.title.copyWith(color: c.text),
          ),
          const SizedBox(height: Space.xs),
          Text(hint, style: T.small.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.base),
          Center(
            child: AmountDisplay(
              cents: _amount.value,
              size: 44,
              color: c.primary,
            ),
          ),
          const SizedBox(height: Space.md),
          QuickAddChips(controller: _amount),
          const SizedBox(height: Space.sm),
          Keypad(controller: _amount),
          const SizedBox(height: Space.md),
          AppField(controller: _name, placeholder: ph, maxLength: 40),
          if (widget.type == MovementType.spend) ...[
            const SizedBox(height: Space.md),
            Segmented<Recurrence>(
              value: _rec,
              options: const {
                Recurrence.once: 'Uma vez',
                Recurrence.monthly: 'Todo ciclo',
              },
              onChanged: (r) => setState(() => _rec = r),
            ),
          ],
          const SizedBox(height: Space.md),
          SelectField(
            leading: Icon(
              LucideIcons.calendar,
              size: 18,
              color: c.textSecondary,
            ),
            value: DateFormat("d 'de' MMMM 'de' y", 'pt_BR').format(_date),
            placeholder: '',
            onTap: () =>
                pickDate(context, _date, (d) => setState(() => _date = d)),
          ),
          const SizedBox(height: Space.base),
          PillButton(
            widget.existing == null
                ? switch (widget.type) {
                    MovementType.deposit => 'Guardar valor',
                    MovementType.spend => 'Registrar uso',
                    MovementType.redeem => 'Resgatar valor',
                  }
                : 'Salvar alterações',
            onTap: valid ? _save : null,
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: Space.sm),
            if (widget.existing!.recurrence == Recurrence.monthly &&
                widget.existing!.endDate == null) ...[
              PillButton(
                'Parar de repetir após este ciclo',
                kind: BtnKind.ghost,
                onTap: () {
                  context.storeRead.endMovement(
                    widget.boxId,
                    widget.existing!.id,
                  );
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: Space.sm),
            ],
            PillButton(
              'Excluir',
              kind: BtnKind.danger,
              onTap: () {
                context.storeRead.deleteMovement(
                  widget.boxId,
                  widget.existing!.id,
                );
                Navigator.pop(context);
                toast(
                  context,
                  'Movimentação excluída',
                  icon: LucideIcons.trash2,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _save() {
    final s = context.storeRead;
    final name = _name.text.trim().isEmpty
        ? switch (widget.type) {
            MovementType.deposit => 'Extra',
            MovementType.spend => 'Gasto',
            MovementType.redeem => 'Resgate',
          }
        : _name.text.trim();
    final m = Movement(
      id: widget.existing?.id,
      name: name,
      cents: _amount.value,
      type: widget.type,
      date: _date,
      recurrence: widget.type == MovementType.spend ? _rec : Recurrence.once,
      endDate: widget.existing?.endDate,
    );
    if (widget.existing == null) {
      s.addMovement(widget.boxId, m);
    } else {
      s.updateMovement(widget.boxId, m);
    }
    Navigator.pop(context);
    toast(context, 'Movimentação salva');
  }
}
