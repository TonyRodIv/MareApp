import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'shell.dart';

class SplitScreen extends StatelessWidget {
  final bool embedded;
  const SplitScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final bills = s.data.splitBills;
    final hidden = s.data.hideValues;
    final maxW = isWide(context) ? 920.0 : 720.0;
    final pad = sidePadding(context, maxWidth: maxW);

    var toReceive = 0;
    var toPay = 0;
    for (final b in bills) {
      for (var i = 0; i < b.participants.length; i++) {
        final p = b.participants[i];
        if (!p.isMe) continue;
        final net = b.netFor(i);
        if (net > 0 && !b.isFullySettled) toReceive += net;
        if (net < 0 && !p.settled) toPay += -net;
      }
    }

    final scroll = CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        PinnedCupertinoBar(
          height: 60,
          maxWidth: maxW,
          builder: (ctx, progress) => Row(
            children: [
              if (embedded) ...[
                Expanded(
                  child: Text(
                    'Dividir gastos',
                    style: T.pageTitle.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else ...[
                const BackChevron(),
                Expanded(
                  child: BarTitle('Dividir gastos', progress: progress),
                ),
              ],
              Builder(
                builder: (_) {
                  final (btnBg, btnFg) = softActionTone(
                    c.palette.primary[500],
                    isDark: c.isDark,
                  );
                  return RoundIconButton(
                    LucideIcons.plus,
                    size: 44,
                    label: 'Nova divisão',
                    bg: btnBg,
                    fg: btnFg,
                    onTap: () => openSplitForm(context),
                  );
                },
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            pad,
            embedded ? Space.base : Space.sm,
            pad,
            embedded
                ? navClearance(context)
                : Space.xl + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.list(
            children: [
              if (!embedded) ...[
                LargeTitle('Dividir gastos', style: T.pageTitle),
                const SizedBox(height: Space.lg),
              ],
              if (bills.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(Space.base),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'A receber',
                              style: T.small.copyWith(color: c.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            MoneyText(
                              toReceive,
                              hidden: hidden,
                              style: T.cardValue.copyWith(
                                color: toReceive > 0 ? c.positive : c.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.all(Space.base),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Você deve',
                              style: T.small.copyWith(color: c.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            MoneyText(
                              toPay,
                              hidden: hidden,
                              style: T.cardValue.copyWith(
                                color: toPay > 0 ? c.negative : c.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
              ],
              if (bills.isEmpty)
                EmptyState(
                  icon: LucideIcons.users,
                  title: 'Nenhuma divisão ainda',
                  message:
                      'Divida contas de jantar, viagem ou rolês e acompanhe quem já pagou.',
                  action: 'Nova divisão',
                  onAction: () => openSplitForm(context),
                )
              else
                ListGroup(
                  gap: 18,
                  children: [
                    for (final b in bills)
                      ListRow(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: b.isFullySettled
                                ? c.positive.withValues(alpha: 0.14)
                                : c.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            b.isFullySettled
                                ? LucideIcons.check
                                : LucideIcons.users,
                            size: 20,
                            color: b.isFullySettled ? c.positive : c.primary,
                          ),
                        ),
                        title: b.title,
                        subtitle:
                            '${b.participants.length} pessoas · ${fmtMoney(b.shareFor(0), hidden: hidden)}/pessoa',
                        value: fmtMoney(b.totalCents, hidden: hidden),
                        arrow: true,
                        onTap: () => _openSplitDetail(context, b.id),
                      ),
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
        embedded ? scroll : CollapsingTitleScope(child: scroll),
      ],
    );
    if (embedded) return body;
    return SheetScaler(
      child: CupertinoPageScaffold(backgroundColor: c.bg, child: body),
    );
  }
}

Future<void> _openSplitDetail(BuildContext context, String billId) {
  return showSheet<void>(
    context,
    builder: (ctx) {
      final c = ctx.c;
      final s = ctx.store;
      final bill = s.data.splitBills.where((b) => b.id == billId).firstOrNull;
      if (bill == null) return const SizedBox.shrink();
      final hidden = s.data.hideValues;

      return SheetBody(
        bottom: Row(
          children: [
            Expanded(
              child: PillButton(
                'Editar',
                kind: BtnKind.secondary,
                icon: LucideIcons.pencil,
                onTap: () {
                  Navigator.pop(ctx);
                  openSplitForm(context, existing: bill);
                },
              ),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: PillButton(
                'Excluir',
                kind: BtnKind.danger,
                icon: LucideIcons.trash2,
                onTap: () async {
                  final ok = await confirm(
                    ctx,
                    title: 'Excluir divisão?',
                    message: 'Remover "${bill.title}" da lista.',
                    action: 'Excluir',
                  );
                  if (ok && ctx.mounted) {
                    s.deleteSplitBill(bill.id);
                    Navigator.pop(ctx);
                  }
                },
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bill.title, style: T.title.copyWith(color: c.text)),
                      const SizedBox(height: 2),
                      Text(
                        'Total ${fmtMoney(bill.totalCents, hidden: hidden)} · ${fmtMoney(bill.shareFor(0), hidden: hidden)} por pessoa',
                        style: T.small.copyWith(color: c.textSecondary),
                      ),
                    ],
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
            const SizedBox(height: Space.base),
            ListGroup(
              bg: c.isDark ? c.cardAlt : c.surfaceLow,
              children: [
                for (var i = 0; i < bill.participants.length; i++)
                  () {
                    final p = bill.participants[i];
                    final net = bill.netFor(i);
                    final settled = p.settled || net >= 0;
                    final status = net > 0
                        ? 'Recebe ${fmtMoney(net, hidden: hidden)}'
                        : net == 0
                            ? 'Quitado'
                            : p.settled
                                ? 'Pago'
                                : 'Deve ${fmtMoney(-net, hidden: hidden)}';
                    final statusColor = net > 0
                        ? c.positive
                        : settled
                            ? c.positive
                            : c.negative;
                    return ListRow(
                      leading: Avatar(name: p.name, size: 36),
                      title: p.name,
                      subtitle: p.paidCents > 0
                          ? 'Pagou ${fmtMoney(p.paidCents, hidden: hidden)}'
                          : 'Não pagou ainda',
                      value: status,
                      valueColor: statusColor,
                      trailing: net < 0
                          ? CupertinoSwitch(
                              value: p.settled,
                              activeTrackColor: c.positive,
                              onChanged: (_) =>
                                  s.toggleSplitSettled(bill.id, p.id),
                            )
                          : null,
                      onTap: net < 0
                          ? () => s.toggleSplitSettled(bill.id, p.id)
                          : null,
                    );
                  }(),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<void> openSplitForm(BuildContext context, {SplitBill? existing}) {
  return showSheet<void>(
    context,
    builder: (_) => _SplitFormSheet(existing: existing),
  );
}

class _PersonDraft {
  final String id;
  final TextEditingController name;
  final TextEditingController paid;
  final bool isMe;

  _PersonDraft({
    required this.id,
    required String initialName,
    Cents initialPaid = 0,
    this.isMe = false,
  }) : name = TextEditingController(text: initialName),
       paid = TextEditingController(
         text: initialPaid > 0 ? (initialPaid / 100).toStringAsFixed(2) : '',
       );

  void dispose() {
    name.dispose();
    paid.dispose();
  }
}

class _SplitFormSheet extends StatefulWidget {
  final SplitBill? existing;
  const _SplitFormSheet({this.existing});

  @override
  State<_SplitFormSheet> createState() => _SplitFormSheetState();
}

class _SplitFormSheetState extends State<_SplitFormSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _total = TextEditingController(
    text: widget.existing != null && widget.existing!.totalCents > 0
        ? (widget.existing!.totalCents / 100).toStringAsFixed(2)
        : '',
  );
  late final List<_PersonDraft> _people;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null && widget.existing!.participants.isNotEmpty) {
      _people = [
        for (final p in widget.existing!.participants)
          _PersonDraft(
            id: p.id,
            initialName: p.name,
            initialPaid: p.paidCents,
            isMe: p.isMe,
          ),
      ];
    } else {
      _people = [
        _PersonDraft(id: 'me', initialName: 'Você', isMe: true),
        _PersonDraft(id: 'p2', initialName: 'Pessoa 2'),
      ];
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    for (final p in _people) {
      p.dispose();
    }
    super.dispose();
  }

  Cents get _totalCents => parseMoney(_total.text) ?? 0;

  void _addPerson() {
    setState(() {
      final n = _people.length + 1;
      _people.add(
        _PersonDraft(
          id: 'p_${DateTime.now().microsecondsSinceEpoch}_$n',
          initialName: 'Pessoa $n',
        ),
      );
    });
  }

  void _markPaidAll(int idx) {
    final tot = _totalCents;
    if (tot <= 0) return;
    setState(() {
      for (var i = 0; i < _people.length; i++) {
        _people[i].paid.text = i == idx ? (tot / 100).toStringAsFixed(2) : '';
      }
    });
  }

  void _save() {
    final title = _title.text.trim();
    final total = _totalCents;
    if (title.isEmpty || total <= 0 || _people.length < 2) {
      toast(
        context,
        'Informe título, valor e pelo menos 2 pessoas',
        icon: LucideIcons.triangleAlert,
      );
      return;
    }
    final participants = [
      for (var i = 0; i < _people.length; i++)
        SplitParticipant(
          id: _people[i].id,
          name: _people[i].name.text.trim().isEmpty
              ? 'Pessoa ${i + 1}'
              : _people[i].name.text.trim(),
          paidCents: parseMoney(_people[i].paid.text) ?? 0,
          isMe: _people[i].isMe,
          settled: widget.existing?.participants
                  .where((x) => x.id == _people[i].id)
                  .firstOrNull
                  ?.settled ??
              false,
        ),
    ];
    final s = context.storeRead;
    if (widget.existing != null) {
      s.updateSplitBill(
        SplitBill(
          id: widget.existing!.id,
          title: title,
          totalCents: total,
          date: widget.existing!.date,
          participants: participants,
        ),
      );
    } else {
      s.addSplitBill(
        SplitBill(
          id: 'sp_${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          totalCents: total,
          date: DateTime.now(),
          participants: participants,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tot = _totalCents;
    final perPerson = _people.isEmpty ? 0 : (tot ~/ _people.length);
    final fieldBg = c.isDark ? c.cardAlt : c.surfaceLow;

    return SheetBody(
      bottom: PillButton(
        widget.existing != null ? 'Salvar alterações' : 'Criar divisão',
        onTap: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.existing != null ? 'Editar divisão' : 'Nova divisão',
                  style: T.title.copyWith(color: c.text),
                ),
              ),
              RoundIconButton(
                LucideIcons.x,
                size: 36,
                bg: c.cardAlt,
                label: 'Fechar',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Space.base),
          const FieldLabel('Descrição'),
          AppField(
            controller: _title,
            bg: fieldBg,
            placeholder: 'Jantar, viagem, mercado…',
            capitalization: TextCapitalization.sentences,
            maxLength: 40,
          ),
          const SizedBox(height: Space.md),
          const FieldLabel('Valor total'),
          AppField(
            controller: _total,
            bg: fieldBg,
            placeholder: 'R\$ 0,00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.base),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pessoas (${_people.length})',
                  style: T.headline.copyWith(color: c.text),
                ),
              ),
              ChipButton(
                'Adicionar',
                icon: LucideIcons.plus,
                bg: fieldBg,
                onTap: _addPerson,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          for (var i = 0; i < _people.length; i++) ...[
            Container(
              margin: const EdgeInsets.only(bottom: Space.sm),
              padding: const EdgeInsets.all(Space.md),
              decoration: ShapeDecoration(
                color: fieldBg,
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
                        child: CupertinoTextField(
                          controller: _people[i].name,
                          placeholder: 'Nome',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          style: T.bodyStrong.copyWith(color: c.text),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      SizedBox(
                        width: 112,
                        child: CupertinoTextField(
                          controller: _people[i].paid,
                          placeholder: 'Pagou R\$',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          style: T.body.copyWith(color: c.text),
                          decoration: BoxDecoration(
                            color: c.card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_people.length > 2 && !_people[i].isMe) ...[
                        const SizedBox(width: Space.xs),
                        Pressable(
                          semanticLabel: 'Remover pessoa',
                          onTap: () => setState(() {
                            _people[i].dispose();
                            _people.removeAt(i);
                          }),
                          child: Icon(
                            LucideIcons.trash2,
                            size: 18,
                            color: c.negative,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (tot > 0) ...[
                    const SizedBox(height: Space.xs),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ChipButton(
                        'Pagou tudo',
                        bg: c.card,
                        onTap: () => _markPaidAll(i),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (tot > 0) ...[
            const SizedBox(height: Space.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.md),
              decoration: ShapeDecoration(
                color: c.primarySoft,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.users, size: 18, color: c.primary),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'Fica ${fmtMoney(perPerson)} por pessoa',
                      style: T.bodyStrong.copyWith(color: c.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
