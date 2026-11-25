import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'shell.dart';

enum _SplitFilter { all, open, monthly, settled }

class _Transfer {
  final String from;
  final String to;
  final Cents cents;
  const _Transfer(this.from, this.to, this.cents);
}

List<_Transfer> _computeHouseTransfers(List<SplitBill> bills) {
  final balances = <String, Cents>{};
  final displayNames = <String, String>{};
  for (final b in bills) {
    if (b.isFullySettled) continue;
    for (var i = 0; i < b.participants.length; i++) {
      final p = b.participants[i];
      final net = b.netFor(i);
      if (net < 0 && p.settled) continue;
      final key = p.name.trim().toLowerCase();
      displayNames.putIfAbsent(key, () => p.name.trim());
      balances[key] = (balances[key] ?? 0) + net;
    }
  }
  final debtors = <MapEntry<String, Cents>>[];
  final creditors = <MapEntry<String, Cents>>[];
  for (final e in balances.entries) {
    if (e.value < -1) debtors.add(MapEntry(e.key, -e.value));
    if (e.value > 1) creditors.add(MapEntry(e.key, e.value));
  }
  debtors.sort((a, b) => b.value.compareTo(a.value));
  creditors.sort((a, b) => b.value.compareTo(a.value));

  final out = <_Transfer>[];
  var di = 0;
  var ci = 0;
  while (di < debtors.length && ci < creditors.length) {
    final d = debtors[di];
    final cr = creditors[ci];
    final amt = math.min(d.value, cr.value);
    if (amt > 0) {
      out.add(
        _Transfer(
          displayNames[d.key] ?? d.key,
          displayNames[cr.key] ?? cr.key,
          amt,
        ),
      );
    }
    debtors[di] = MapEntry(d.key, d.value - amt);
    creditors[ci] = MapEntry(cr.key, cr.value - amt);
    if (debtors[di].value <= 0) di++;
    if (creditors[ci].value <= 0) ci++;
  }
  return out;
}

class SplitScreen extends StatefulWidget {
  final bool embedded;
  const SplitScreen({super.key, this.embedded = false});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  _SplitFilter _filter = _SplitFilter.all;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final bills = s.data.splitBills;
    final hidden = s.data.hideValues;
    final maxW = isWide(context) ? 960.0 : 720.0;
    final pad = sidePadding(context, maxWidth: maxW);

    var toReceive = 0;
    var toPay = 0;
    var totalAll = 0;
    var settledAll = 0;
    final personNet = <String, Cents>{};
    final personDisplay = <String, String>{};

    for (final b in bills) {
      totalAll += b.totalCents;
      if (b.isFullySettled) settledAll += b.totalCents;
      for (var i = 0; i < b.participants.length; i++) {
        final p = b.participants[i];
        final net = b.netFor(i);
        final key = p.name.trim().toLowerCase();
        personDisplay.putIfAbsent(key, () => p.name.trim());
        if (!p.isMe) {
          final eff = (net < 0 && p.settled) ? 0 : net;
          personNet[key] = (personNet[key] ?? 0) + eff;
        } else {
          if (net > 0 && !b.isFullySettled) toReceive += net;
          if (net < 0 && !p.settled) toPay += -net;
        }
      }
    }

    final netHouse = toReceive - toPay;
    final transfers = _computeHouseTransfers(bills);
    final filtered = switch (_filter) {
      _SplitFilter.all => bills,
      _SplitFilter.open => [
        for (final b in bills)
          if (!b.isFullySettled) b,
      ],
      _SplitFilter.monthly => [
        for (final b in bills)
          if (b.isMonthly) b,
      ],
      _SplitFilter.settled => [
        for (final b in bills)
          if (b.isFullySettled) b,
      ],
    };

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
              if (widget.embedded) ...[
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
            widget.embedded ? Space.base : Space.sm,
            pad,
            widget.embedded
                ? navClearance(context)
                : Space.xl + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverList.list(
            children: [
              if (!widget.embedded) ...[
                LargeTitle('Dividir gastos', style: T.pageTitle),
                const SizedBox(height: Space.lg),
              ],
              if (bills.isNotEmpty) ...[
                // Resumo visual da casa
                AppCard(
                  padding: const EdgeInsets.all(Space.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Saldo da casa',
                              style: T.label.copyWith(color: c.textSecondary),
                            ),
                          ),
                          Tag(
                            netHouse == 0
                                ? 'Tudo em dia'
                                : (netHouse > 0 ? 'Saldo a favor' : 'Em débito'),
                            bg: netHouse >= 0
                                ? c.positive.withValues(alpha: 0.14)
                                : c.negative.withValues(alpha: 0.14),
                            fg: netHouse >= 0 ? c.positive : c.negative,
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      MoneyText(
                        netHouse.abs(),
                        hidden: hidden,
                        style: T.displayLg.copyWith(
                          color: netHouse == 0
                              ? c.text
                              : (netHouse > 0 ? c.positive : c.negative),
                        ),
                      ),
                      if (totalAll > 0) ...[
                        const SizedBox(height: Space.md),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 10,
                            child: Row(
                              children: [
                                if (settledAll > 0)
                                  Expanded(
                                    flex: settledAll,
                                    child: Container(color: c.positive),
                                  ),
                                if (totalAll - settledAll > 0)
                                  Expanded(
                                    flex: totalAll - settledAll,
                                    child: Container(color: c.primary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quitado ${fmtMoney(settledAll, hidden: hidden)}',
                              style: T.micro.copyWith(color: c.textSecondary),
                            ),
                            Text(
                              'Em aberto ${fmtMoney(totalAll - settledAll, hidden: hidden)}',
                              style: T.micro.copyWith(color: c.textSecondary),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: Space.md),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(Space.md),
                              decoration: ShapeDecoration(
                                color: c.isDark ? c.cardAlt : c.surfaceLow,
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'A receber',
                                    style: T.small.copyWith(
                                      color: c.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  MoneyText(
                                    toReceive,
                                    hidden: hidden,
                                    style: T.headline.copyWith(
                                      color: toReceive > 0 ? c.positive : c.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(Space.md),
                              decoration: ShapeDecoration(
                                color: c.isDark ? c.cardAlt : c.surfaceLow,
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Você deve',
                                    style: T.small.copyWith(
                                      color: c.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  MoneyText(
                                    toPay,
                                    hidden: hidden,
                                    style: T.headline.copyWith(
                                      color: toPay > 0 ? c.negative : c.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (personNet.isNotEmpty) ...[
                  const SizedBox(height: Space.lg),
                  const SectionHeader('Moradores'),
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final e in personNet.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: Space.sm),
                            child: Pressable(
                              scale: 0.96,
                              onTap: () => _openPersonSheet(
                                context,
                                personDisplay[e.key] ?? e.key,
                              ),
                              child: Container(
                                width: 136,
                                padding: const EdgeInsets.all(Space.md),
                                decoration: ShapeDecoration(
                                  color: c.card,
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Avatar(
                                          name: personDisplay[e.key] ?? e.key,
                                          size: 28,
                                        ),
                                        const Spacer(),
                                        Icon(
                                          LucideIcons.chevronRight,
                                          size: 14,
                                          color: c.textTertiary,
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      personDisplay[e.key] ?? e.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.bodyStrong.copyWith(
                                        color: c.text,
                                      ),
                                    ),
                                    Text(
                                      e.value == 0
                                          ? 'Em dia'
                                          : (e.value < 0
                                                ? 'Deve ${fmtMoney(-e.value, hidden: hidden)}'
                                                : 'Recebe ${fmtMoney(e.value, hidden: hidden)}'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.micro.copyWith(
                                        color: e.value == 0
                                            ? c.positive
                                            : (e.value < 0
                                                  ? c.negative
                                                  : c.positive),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (transfers.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  ListGroup(
                    title: 'Acerto da casa',
                    gap: 14,
                    children: [
                      for (final tr in transfers)
                        ListRow(
                          leading: Icon(
                            LucideIcons.arrowLeftRight,
                            size: 18,
                            color: c.primary,
                          ),
                          title: '${tr.from} → ${tr.to}',
                          value: fmtMoney(tr.cents, hidden: hidden),
                          valueColor: c.primary,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: Space.lg),
                Segmented<_SplitFilter>(
                  value: _filter,
                  options: const {
                    _SplitFilter.all: 'Todas',
                    _SplitFilter.open: 'Abertas',
                    _SplitFilter.monthly: 'Fixas',
                    _SplitFilter.settled: 'Quitadas',
                  },
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: Space.md),
              ],
              if (bills.isEmpty)
                EmptyState(
                  icon: LucideIcons.users,
                  title: 'Nenhuma divisão ainda',
                  message:
                      'Divida contas da casa, jantar ou viagens e acompanhe quem já pagou.',
                  action: 'Nova divisão',
                  onAction: () => openSplitForm(context),
                )
              else if (filtered.isEmpty)
                EmptyState(
                  icon: LucideIcons.checkCheck,
                  title: 'Nada neste filtro',
                  message: 'Nenhuma conta corresponde ao filtro selecionado.',
                )
              else
                ListGroup(
                  gap: 18,
                  children: [
                    for (final b in filtered)
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
                                : (b.isMonthly
                                      ? LucideIcons.house
                                      : LucideIcons.users),
                            size: 20,
                            color: b.isFullySettled ? c.positive : c.primary,
                          ),
                        ),
                        title: b.title,
                        subtitle:
                            '${b.isMonthly ? 'Mensal · ' : ''}${b.settledCount}/${b.participants.length} acertados · ${fmtMoney(b.shareFor(0), hidden: hidden)}/pessoa',
                        value: fmtMoney(b.totalCents, hidden: hidden),
                        arrow: true,
                        onTap: () => push(
                          context,
                          SplitDetailScreen(billId: b.id),
                        ),
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
        widget.embedded ? scroll : CollapsingTitleScope(child: scroll),
      ],
    );
    if (widget.embedded) return body;
    return SheetScaler(
      child: CupertinoPageScaffold(backgroundColor: c.bg, child: body),
    );
  }
}

/// Sub-tela com todas as contas de um morador específico e botão de quitar tudo.
Future<void> _openPersonSheet(BuildContext context, String personName) {
  final key = personName.trim().toLowerCase();
  return showSheet<void>(
    context,
    builder: (ctx) {
      final c = ctx.c;
      final s = ctx.store;
      final hidden = s.data.hideValues;
      final items = <(SplitBill, int, SplitParticipant)>[];
      var pending = 0;
      for (final b in s.data.splitBills) {
        for (var i = 0; i < b.participants.length; i++) {
          final p = b.participants[i];
          if (p.name.trim().toLowerCase() == key) {
            items.add((b, i, p));
            final net = b.netFor(i);
            if (net < 0 && !p.settled) pending += -net;
          }
        }
      }

      return SheetBody(
        bottom: pending > 0
            ? PillButton(
                'Quitar tudo (${fmtMoney(pending, hidden: hidden)})',
                icon: LucideIcons.checkCheck,
                onTap: () {
                  s.settleAllWithPerson(personName);
                  Navigator.pop(ctx);
                  toast(context, 'Pendências de $personName quitadas');
                },
              )
            : PillButton('Fechar', onTap: () => Navigator.pop(ctx)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(name: personName, size: 44),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(personName, style: T.title.copyWith(color: c.text)),
                      Text(
                        pending > 0
                            ? 'Deve ${fmtMoney(pending, hidden: hidden)} no total'
                            : 'Sem pendências em aberto',
                        style: T.small.copyWith(
                          color: pending > 0 ? c.negative : c.positive,
                        ),
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
                for (final (b, i, p) in items)
                  () {
                    final net = b.netFor(i);
                    final settled = p.settled || net >= 0;
                    return ListRow(
                      title: b.title,
                      subtitle:
                          'Parte ${fmtMoney(b.shareFor(i), hidden: hidden)} · Pagou ${fmtMoney(p.paidCents, hidden: hidden)}',
                      value: net > 0
                          ? '+${fmtMoney(net, hidden: hidden)}'
                          : (settled
                                ? 'Quitado'
                                : '-${fmtMoney(-net, hidden: hidden)}'),
                      valueColor: settled ? c.positive : c.negative,
                      onTap: net < 0
                          ? () => s.toggleSplitSettled(b.id, p.id)
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

/// Sub-tela dedicada ao detalhe de uma conta dividida.
class SplitDetailScreen extends StatelessWidget {
  final String billId;
  const SplitDetailScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final bill = s.data.splitBills.where((b) => b.id == billId).firstOrNull;
    if (bill == null) {
      return SheetScaler(
        child: CupertinoPageScaffold(
          backgroundColor: c.bg,
          child: SafeArea(
            child: Center(
              child: PillButton(
                'Voltar',
                expand: false,
                onTap: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      );
    }

    final hidden = s.data.hideValues;
    final maxW = isWide(context) ? 820.0 : 680.0;
    final pad = sidePadding(context, maxWidth: maxW);
    final progress = bill.participants.isEmpty
        ? 1.0
        : bill.settledCount / bill.participants.length;

    return SheetScaler(
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: Stack(
          children: [
            const GlowBackground(height: 440),
            CollapsingTitleScope(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  PinnedCupertinoBar(
                    height: 60,
                    maxWidth: maxW,
                    builder: (ctx, p) => Row(
                      children: [
                        const BackChevron(),
                        Expanded(child: BarTitle(bill.title, progress: p)),
                        RoundIconButton(
                          LucideIcons.pencil,
                          size: 40,
                          glass: true,
                          label: 'Editar divisão',
                          onTap: () => openSplitForm(context, existing: bill),
                        ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      pad,
                      Space.sm,
                      pad,
                      Space.xl + MediaQuery.paddingOf(context).bottom,
                    ),
                    sliver: SliverList.list(
                      children: [
                        LargeTitle(bill.title, style: T.pageTitle),
                        const SizedBox(height: Space.base),
                        AppCard(
                          padding: const EdgeInsets.all(Space.gutter),
                          child: Row(
                            children: [
                              ProgressRing(
                                size: 64,
                                stroke: 6,
                                fraction: progress,
                                color: bill.isFullySettled
                                    ? c.positive
                                    : c.primary,
                                track: c.cardAlt,
                                child: Text(
                                  '${bill.settledCount}/${bill.participants.length}',
                                  style: T.smallStrong.copyWith(color: c.text),
                                ),
                              ),
                              const SizedBox(width: Space.base),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MoneyText(
                                      bill.totalCents,
                                      hidden: hidden,
                                      style: T.title,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${bill.settledCount} de ${bill.participants.length} acertados${bill.isMonthly ? ' · Mensal' : ''}',
                                      style: T.small.copyWith(
                                        color: c.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.lg),
                        ListGroup(
                          title: 'Participantes',
                          children: [
                            for (var i = 0; i < bill.participants.length; i++)
                              () {
                                final p = bill.participants[i];
                                final share = bill.shareFor(i);
                                final net = bill.netFor(i);
                                final settled = p.settled || net >= 0;
                                final status = net > 0
                                    ? 'Recebe ${fmtMoney(net, hidden: hidden)}'
                                    : net == 0
                                        ? 'Quitado'
                                        : p.settled
                                            ? 'Pago'
                                            : 'Deve ${fmtMoney(-net, hidden: hidden)}';
                                return ListRow(
                                  leading: Avatar(name: p.name, size: 38),
                                  title: p.name,
                                  subtitle:
                                      'Parte ${fmtMoney(share, hidden: hidden)} · ${p.paidCents > 0 ? 'Pagou ${fmtMoney(p.paidCents, hidden: hidden)}' : 'Não pagou ainda'}',
                                  value: status,
                                  valueColor: settled ? c.positive : c.negative,
                                  trailing: net < 0
                                      ? CupertinoSwitch(
                                          value: p.settled,
                                          activeTrackColor: c.positive,
                                          onChanged: (_) => s
                                              .toggleSplitSettled(bill.id, p.id),
                                        )
                                      : null,
                                  onTap: net < 0
                                      ? () =>
                                          s.toggleSplitSettled(bill.id, p.id)
                                      : null,
                                );
                              }(),
                          ],
                        ),
                        const SizedBox(height: Space.lg),
                        if (bill.isMonthly) ...[
                          PillButton(
                            'Repetir para este mês',
                            icon: LucideIcons.copy,
                            kind: BtnKind.secondary,
                            onTap: () {
                              s.duplicateSplitBill(bill.id);
                              toast(context, 'Conta duplicada para este mês');
                            },
                          ),
                          const SizedBox(height: Space.sm),
                        ],
                        PillButton(
                          'Excluir divisão',
                          icon: LucideIcons.trash2,
                          kind: BtnKind.danger,
                          onTap: () async {
                            final ok = await confirm(
                              context,
                              title: 'Excluir divisão?',
                              message: 'Remover "${bill.title}" da lista.',
                              action: 'Excluir',
                            );
                            if (ok && context.mounted) {
                              s.deleteSplitBill(bill.id);
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
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
  final TextEditingController customShare;
  final bool isMe;

  _PersonDraft({
    required this.id,
    required String initialName,
    Cents initialPaid = 0,
    Cents? initialCustomShare,
    this.isMe = false,
  }) : name = TextEditingController(text: initialName),
       paid = TextEditingController(
         text: initialPaid > 0 ? (initialPaid / 100).toStringAsFixed(2) : '',
       ),
       customShare = TextEditingController(
         text: initialCustomShare != null && initialCustomShare > 0
             ? (initialCustomShare / 100).toStringAsFixed(2)
             : '',
       );

  void dispose() {
    name.dispose();
    paid.dispose();
    customShare.dispose();
  }
}

class _SplitFormSheet extends StatefulWidget {
  final SplitBill? existing;
  const _SplitFormSheet({this.existing});

  @override
  State<_SplitFormSheet> createState() => _SplitFormSheetState();
}

class _SplitFormSheetState extends State<_SplitFormSheet> {
  static const _houseSuggestions = [
    'Aluguel',
    'Internet',
    'Energia',
    'Água',
    'Mercado',
    'Limpeza',
    'Jantar',
  ];

  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _total = TextEditingController(
    text: widget.existing != null && widget.existing!.totalCents > 0
        ? (widget.existing!.totalCents / 100).toStringAsFixed(2)
        : '',
  );
  late bool _isMonthly = widget.existing?.isMonthly ?? false;
  late bool _customShares =
      widget.existing?.participants.any((p) => p.customShareCents != null) ??
      false;
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
            initialCustomShare: p.customShareCents,
            isMe: p.isMe,
          ),
      ];
    } else {
      _people = [
        _PersonDraft(id: 'me', initialName: 'Você', isMe: true),
        _PersonDraft(id: 'p2', initialName: 'Morador 2'),
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
          initialName: 'Morador $n',
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
        'Informe descrição, valor e pelo menos 2 pessoas',
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
          customShareCents: _customShares
              ? parseMoney(_people[i].customShare.text)
              : null,
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
          isMonthly: _isMonthly,
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
          isMonthly: _isMonthly,
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
            placeholder: 'Aluguel, internet, mercado…',
            capitalization: TextCapitalization.sentences,
            maxLength: 40,
          ),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in _houseSuggestions)
                ChipButton(
                  s,
                  bg: fieldBg,
                  onTap: () => setState(() => _title.text = s),
                ),
            ],
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
          const SizedBox(height: Space.sm),
          ListGroup(
            bg: fieldBg,
            children: [
              ListRow(
                leading: Icon(LucideIcons.house, size: 18, color: c.primary),
                title: 'Conta fixa da casa (mensal)',
                trailing: CupertinoSwitch(
                  value: _isMonthly,
                  activeTrackColor: c.primary,
                  onChanged: (v) => setState(() => _isMonthly = v),
                ),
                onTap: () => setState(() => _isMonthly = !_isMonthly),
              ),
              ListRow(
                leading: Icon(
                  LucideIcons.slidersHorizontal,
                  size: 18,
                  color: c.textSecondary,
                ),
                title: 'Valores diferentes por pessoa',
                trailing: CupertinoSwitch(
                  value: _customShares,
                  activeTrackColor: c.primary,
                  onChanged: (v) => setState(() => _customShares = v),
                ),
                onTap: () => setState(() => _customShares = !_customShares),
              ),
            ],
          ),
          const SizedBox(height: Space.base),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Moradores / Pessoas (${_people.length})',
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
                  if (_customShares) ...[
                    const SizedBox(height: Space.xs),
                    CupertinoTextField(
                      controller: _people[i].customShare,
                      placeholder: 'Parte fixa (deixe vazio para dividir o resto)',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      style: T.small.copyWith(color: c.text),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
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
          if (tot > 0 && !_customShares) ...[
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
