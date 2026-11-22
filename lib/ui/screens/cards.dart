import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/brands.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'add_expense.dart';
import 'extrato.dart';
import 'shell.dart';

/// Linha "Contas +" da Carteira (aparece quando o usuário adiciona contas ou cartões).
/// O container rolável vai até a borda direita da tela; o fade esquerdo só aparece
/// quando há conteúdo rolado para a esquerda, e o direito só quando há mais à direita.
class CardsStrip extends StatefulWidget {
  final bool hidden;
  final double leftPadding;
  final double rightPadding;
  const CardsStrip({
    super.key,
    required this.hidden,
    this.leftPadding = 0,
    this.rightPadding = Space.gutter,
  });

  @override
  State<CardsStrip> createState() => _CardsStripState();
}

class _CardsStripState extends State<CardsStrip> {
  final _scroll = ScrollController();
  double _leftFade = 0;
  double _rightFade = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncFade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFade());
  }

  @override
  void didUpdateWidget(CardsStrip old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFade());
  }

  void _syncFade() {
    if (!mounted || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (!pos.hasContentDimensions) return;
    final left = (pos.pixels / 16.0).clamp(0.0, 1.0);
    final right = ((pos.maxScrollExtent - pos.pixels) / 16.0).clamp(0.0, 1.0);
    if ((left - _leftFade).abs() > 0.02 || (right - _rightFade).abs() > 0.02) {
      setState(() {
        _leftFade = left;
        _rightFade = right;
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncFade);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final cards = s.data.cards;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(width: widget.leftPadding),
          Text('Contas', style: T.body.copyWith(color: c.text)),
          const SizedBox(width: Space.sm),
          RoundIconButton(
            LucideIcons.plus,
            size: 32,
            label: 'Nova conta ou cartão',
            onTap: () => editCard(context),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: cards.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(right: widget.rightPadding),
                    child: Text(
                      'Separe gastos por conta ou cartão',
                      style: T.small.copyWith(color: c.textSecondary),
                    ),
                  )
                : NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      _syncFade();
                      return false;
                    },
                    child: ShaderMask(
                      shaderCallback: (r) => LinearGradient(
                        colors: [
                          Color.fromRGBO(255, 255, 255, 1.0 - _leftFade),
                          const Color(0xFFFFFFFF),
                          const Color(0xFFFFFFFF),
                          Color.fromRGBO(255, 255, 255, 1.0 - _rightFade),
                        ],
                        stops: const [0.0, 0.07, 0.90, 1.0],
                      ).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: ListView.separated(
                        controller: _scroll,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(right: widget.rightPadding),
                        itemCount: cards.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: Space.sm),
                        itemBuilder: (_, i) => Pressable(
                          onTap: () => pushMorph(
                            context,
                            CardDetailScreen(
                              cardId: cards[i].id,
                              heroPrefix: 'home-card',
                            ),
                          ),
                          onLongPress: () => editCard(context, card: cards[i]),
                          child: Hero(
                            tag: 'home-card-badge-${cards[i].id}',
                            flightShuttleBuilder:
                                (_, anim, _, _, _) => _cardToCircleShuttle(
                                  cards[i],
                                  anim,
                                  c,
                                ),
                            child: CardChip(card: cards[i]),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class CardChip extends StatelessWidget {
  final PayCard card;
  final double width;
  const CardChip({super.key, required this.card, this.width = 78});

  @override
  Widget build(BuildContext context) {
    final color = Color(card.color);
    final onColor = color.computeLuminance() > 0.5
        ? Palette.neutral800
        : Palette.neutral0;
    final hasLast4 = card.last4.trim().isNotEmpty;
    final subtitle = card.isCard
        ? (hasLast4 ? '•••${card.last4}' : 'Cartão')
        : 'Conta';
    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Space.radiusSm),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            card.name.isEmpty ? (card.isCard ? 'Cartão' : 'Conta') : card.name,
            style: T.micro.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: T.tiny.copyWith(
                    color: onColor.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (card.isCard)
                BrandBadge(brand: card.brand)
              else
                Icon(
                  LucideIcons.landmark,
                  size: 12,
                  color: onColor.withValues(alpha: 0.9),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class BrandBadge extends StatelessWidget {
  final CardBrand brand;
  final bool bordered;
  const BrandBadge({super.key, required this.brand, this.bordered = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget box(Widget child) => Container(
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: ShapeDecoration(
        color: Palette.neutral0,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(3),
          side: bordered && !c.isDark
              ? BorderSide(color: c.border)
              : BorderSide.none,
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
    switch (brand) {
      case CardBrand.mastercard:
        return box(
          SizedBox(
            width: 16,
            height: 10,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEB001B),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF79E1B).withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case CardBrand.visa:
        return box(
          Text(
            'VISA',
            style: T.tiny.copyWith(
              fontSize: 7,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1F71),
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case CardBrand.elo:
        return box(
          Text(
            'elo',
            style: T.tiny.copyWith(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Palette.neutral800,
            ),
          ),
        );
      case CardBrand.other:
        return box(
          const Icon(
            LucideIcons.creditCard,
            size: 10,
            color: Palette.neutral800,
          ),
        );
    }
  }
}

/// Detecta a cor oficial de bancos/carteiras conhecidos a partir do nome digitado
/// (sem exigir acentos nem caixa exata). Para nomes personalizados, escolhe uma
/// cor fixa da paleta de cartões de forma determinística.
Color bankColorFor(String rawName) {
  final q = foldText(rawName);
  if (q.isEmpty) return cardColors.first;

  for (final (keywords, color) in _knownBankColors) {
    for (final kw in keywords) {
      if (kw.length <= 2) {
        final tokens = q.split(RegExp(r'[^a-z0-9]+'));
        if (tokens.contains(kw)) return color;
      } else if (q.contains(kw)) {
        return color;
      }
    }
  }

  var hash = 0;
  for (final code in q.codeUnits) {
    hash = (hash * 31 + code) & 0x7FFFFFFF;
  }
  return cardColors[hash % cardColors.length];
}

const _knownBankColors = <(List<String>, Color)>[
  (['nubank', 'nuconta', 'ultravioleta', 'nu'], Color(0xFF820AD1)),
  (['itau', 'personnalite', 'credicard', 'iti'], Color(0xFFEC7000)),
  (['bradesco', 'bradescard', 'next'], Color(0xFFCC092F)),
  (['inter'], Color(0xFFFF7A00)),
  (['santander', 'way'], Color(0xFFEC0000)),
  (['banco do brasil', 'ourocard', 'bb'], Color(0xFFE5B800)),
  (['caixa'], Color(0xFF005CA9)),
  (['c6'], Color(0xFF1C1C22)),
  (['mercado pago', 'mercadopago', 'mp'], Color(0xFF009EE3)),
  (['picpay', 'pic pay'], Color(0xFF11C76F)),
  (['pagbank', 'pagseguro'], Color(0xFF00A859)),
  (['btg'], Color(0xFF001E62)),
  (['xp', 'rico', 'clear'], Color(0xFF1A1A1E)),
  (['sicredi'], Color(0xFF3FA110)),
  (['sicoob'], Color(0xFF003641)),
  (['neon'], Color(0xFF00A4DF)),
  (['will'], Color(0xFFFFD900)),
  (['pan'], Color(0xFF00A8E8)),
  (['original'], Color(0xFF00A859)),
  (['safra'], Color(0xFF1C2A48)),
  (['bv'], Color(0xFF0057A8)),
  (['banrisul'], Color(0xFF0066B3)),
  (['brb'], Color(0xFF006CB5)),
  (['stone', 'ton'], Color(0xFF00A868)),
  (['recargapay'], Color(0xFF0089E0)),
  (['99pay'], Color(0xFFFFCA00)),
  (['wise', 'transferwise'], Color(0xFF37517E)),
  (['nomad'], Color(0xFFE5B800)),
  (['revolut'], Color(0xFF191C1F)),
  (['paypal'], Color(0xFF003087)),
  (['apple'], Color(0xFF2C2C2E)),
  (['ame'], Color(0xFFE6005A)),
  (['dinheiro', 'carteira', 'especie'], Color(0xFF2E7D32)),
];

Widget _cardToCircleShuttle(
  PayCard card,
  Animation<double> animation,
  AppColors c,
) {
  final rawColor = Color(card.color);
  final accent = c.tone(rawColor);
  final targetFill = rawColor.withValues(alpha: c.isDark ? 0.18 : 0.12);
  final icon = card.isCard ? LucideIcons.creditCard : LucideIcons.landmark;
  return AnimatedBuilder(
    animation: animation,
    builder: (_, _) {
      final t = Curves.easeInOutCubic.transform(animation.value);
      final bg = Color.lerp(rawColor, targetFill, t) ?? targetFill;
      final iconColor = Color.lerp(
        rawColor.computeLuminance() > 0.5
            ? Palette.neutral800
            : Palette.neutral0,
        accent,
        t,
      )!;
      return LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth.clamp(48.0, 120.0);
          final h = constraints.maxHeight.clamp(44.0, 120.0);
          final radius =
              Space.radiusSm + ((h / 2) - Space.radiusSm) * t;
          return Center(
            child: Container(
              width: w,
              height: h,
              decoration: ShapeDecoration(
                color: bg,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: (18.0 + 22.0 * t).clamp(16.0, 42.0),
                  color: iconColor,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Detalhe de conta ou cartão no mesmo padrão visual de `BoxDetail` (Caixinhas):
/// anel circular centralizado com participação no ciclo, ações rápidas e lista
/// dos lançamentos ligados à conta/cartão.
class CardDetailScreen extends StatelessWidget {
  final String cardId;
  final String? heroPrefix;
  const CardDetailScreen({
    super.key,
    required this.cardId,
    this.heroPrefix,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final card = s.card(cardId);
    if (card == null) {
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
    final cy = f.current;
    final prevCy = cy.prev(s.data.cycleStartDay);

    final items = f
        .expensesIn(cy)
        .where((e) => e.cardId == card.id)
        .toList()
      ..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.cents.compareTo(a.cents);
      });
    final total = items.fold<int>(0, (t, e) => t + e.cents);
    final cycleTotal = f.expensesTotal(cy);
    final share = cycleTotal > 0 ? (total / cycleTotal).clamp(0.0, 1.0) : 0.0;

    final prevTotal = f
        .expensesIn(prevCy)
        .where((e) => e.cardId == card.id)
        .fold<int>(0, (t, e) => t + e.cents);
    final delta = _deltaText(total, prevTotal, hidden);

    final rawColor = Color(card.color);
    final accent = c.tone(rawColor);
    final pad = sidePadding(context, maxWidth: 680);
    final avg = items.isEmpty ? 0 : (total / items.length).round();

    final kindLabel = card.isCard
        ? (card.last4.trim().isNotEmpty
              ? 'Cartão •••${card.last4}'
              : 'Cartão ${_brandLabel(card.brand)}')
        : 'Conta';

    return SheetScaler(
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: Stack(
          children: [
            GlowBackground(
              tint: c.tone(rawColor, min: 2.5),
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
                          card.name,
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
                        onTap: () => _more(context, card),
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
                      // ── Hero circular centralizado (mesmo padrão de Caixinhas)
                      Column(
                        children: [
                          SpringBuilder(
                            value: share,
                            from: 0,
                            spring: Springs.settle,
                            builder: (_, v, _) {
                              final badge = Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: rawColor.withValues(
                                    alpha: c.isDark ? 0.18 : 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  card.isCard
                                      ? LucideIcons.creditCard
                                      : LucideIcons.landmark,
                                  size: 40,
                                  color: accent,
                                ),
                              );
                              return ProgressRing(
                                size: 136,
                                stroke: 8,
                                fraction: v,
                                color: accent,
                                track: c.cardAlt,
                                child: heroPrefix != null
                                    ? Hero(
                                        tag: '$heroPrefix-badge-${card.id}',
                                        flightShuttleBuilder:
                                            (_, anim, _, _, _) =>
                                                _cardToCircleShuttle(
                                                  card,
                                                  anim,
                                                  c,
                                                ),
                                        child: badge,
                                      )
                                    : badge,
                              );
                            },
                          ),
                          const SizedBox(height: Space.lg),
                          Reveal(
                            index: 0,
                            dy: 10,
                            child: Column(
                              children: [
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
                                  cycleTotal > 0
                                      ? '$kindLabel · ${(share * 100).round()}% dos gastos de ${cy.label()}${delta != null ? ' · $delta' : ''}'
                                      : '$kindLabel · Sem gastos em ${cy.label()}',
                                  textAlign: TextAlign.center,
                                  style: T.label.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.lg),

                      // ── Ações rápidas em botões circulares neutros
                      Reveal(
                        index: 1,
                        dy: 12,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CircleAction(
                              icon: LucideIcons.plus,
                              label: 'Novo gasto',
                              onTap: () => openAddExpense(
                                context,
                                initialCardId: card.id,
                              ),
                            ),
                            CircleAction(
                              icon: LucideIcons.pencil,
                              label: 'Editar',
                              onTap: () => editCard(context, card: card),
                            ),
                            CircleAction(
                              icon: LucideIcons.receiptText,
                              label: 'No Extrato',
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).popUntil((r) => r.isFirst);
                                shellNav.goTo(
                                  1,
                                  filter: ExtratoFilter(cardId: card.id),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      if (items.isEmpty) ...[
                        SectionHeader('Gastos em ${cy.label()}'),
                        EmptyState(
                          icon: card.isCard
                              ? LucideIcons.creditCard
                              : LucideIcons.landmark,
                          title: 'Sem gastos nesta conta',
                          message:
                              'Os lançamentos ligados a ${card.name} neste ciclo aparecem aqui.',
                          action: 'Adicionar gasto',
                          onAction: () => openAddExpense(
                            context,
                            initialCardId: card.id,
                          ),
                        ),
                      ] else ...[
                        ListGroup(
                          title: 'Gastos em ${cy.label()}',
                          trailing: Text(
                            '${items.length} ${items.length == 1 ? 'item' : 'itens'}',
                            style: T.smallStrong.copyWith(
                              color: c.textSecondary,
                            ),
                          ),
                          children: [
                            for (final e in items)
                              ExpenseRow(e: e, f: f, hidden: hidden),
                          ],
                        ),
                        const SizedBox(height: Space.base),
                        Text(
                          'Média de ${fmtMoney(avg, hidden: hidden)} por lançamento neste ciclo.',
                          textAlign: TextAlign.center,
                          style: T.small.copyWith(color: c.textTertiary),
                        ),
                      ],
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

  String _brandLabel(CardBrand b) => switch (b) {
    CardBrand.mastercard => 'Mastercard',
    CardBrand.visa => 'Visa',
    CardBrand.elo => 'Elo',
    CardBrand.other => '',
  };

  String? _deltaText(int cur, int prev, bool hidden) {
    if (prev <= 0) return cur > 0 ? 'novo neste ciclo' : null;
    final d = cur - prev;
    if (d == 0) return 'igual ao anterior';
    return '${d > 0 ? '+' : '−'}${fmtMoney(d.abs(), hidden: hidden)} vs. anterior';
  }

  Future<void> _more(BuildContext context, PayCard card) async {
    final s = context.storeRead;
    final a = await actionSheet<String>(
      context,
      title: card.name,
      actions: const [
        SheetAction('Editar conta ou cartão', 'edit', icon: LucideIcons.pencil),
        SheetAction(
          'Excluir',
          'delete',
          destructive: true,
          icon: LucideIcons.trash2,
        ),
      ],
    );
    if (!context.mounted) return;
    if (a == 'edit') {
      editCard(context, card: card);
    } else if (a == 'delete') {
      final ok = await confirm(
        context,
        title: 'Excluir "${card.name}"?',
        message:
            'Os gastos continuam no extrato, só deixam de estar ligados a esta conta.',
        action: 'Excluir',
      );
      if (ok && context.mounted) {
        s.deleteCard(card.id);
        Navigator.pop(context);
        toast(context, 'Conta excluída', icon: LucideIcons.trash2);
      }
    }
  }
}

/// Bottom sheet compacto de criar/editar conta ou cartão:
/// o usuário digita o nome do banco, a cor é ajustada automaticamente pelos
/// bancos conhecidos e, se for cartão, escolhe apenas a bandeira.
Future<void> editCard(BuildContext context, {PayCard? card}) {
  return showSheet<void>(
    context,
    edgeToEdge: true,
    builder: (ctx) => _CardForm(card: card),
  );
}

class _CardForm extends StatefulWidget {
  final PayCard? card;
  const _CardForm({this.card});
  @override
  State<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<_CardForm> {
  late final _name = TextEditingController(text: widget.card?.name ?? '');
  late bool _isCard = widget.card?.isCard ?? false;
  late CardBrand _brand = widget.card?.brand ?? CardBrand.mastercard;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  int get _resolvedColor {
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty) {
      return widget.card?.color ?? cardColors.first.toARGB32();
    }
    return bankColorFor(trimmed).toARGB32();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colorInt = _resolvedColor;
    final trackBg = c.isDark ? c.bg : c.surfaceLow;
    final preview = PayCard(
      id: 'preview',
      name: _name.text.trim(),
      last4: _isCard ? (widget.card?.last4 ?? '') : '',
      color: colorInt,
      brand: _brand,
      isCard: _isCard,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 4, Space.gutter, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.card == null ? 'Nova conta ou cartão' : 'Editar conta',
                  style: T.title.copyWith(
                    color: c.text,
                    decoration: TextDecoration.none,
                  ),
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
          const SizedBox(height: Space.xs),
          Text(
            'Digite o nome do banco — a cor se ajusta automaticamente.',
            style: T.small.copyWith(
              color: c.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: Space.base),
          Center(
            child: SpringBuilder(
              value: colorInt.toDouble(),
              spring: Springs.bouncy,
              builder: (_, _, v) => Transform.rotate(
                angle: (v / 1e9).clamp(-0.04, 0.04),
                child: CardChip(card: preview, width: 156),
              ),
            ),
          ),
          const SizedBox(height: Space.base),
          Segmented<bool>(
            value: _isCard,
            trackColor: trackBg,
            options: const {false: 'Conta', true: 'Cartão'},
            onChanged: (v) => setState(() => _isCard = v),
          ),
          const SizedBox(height: Space.base),
          FieldLabel(_isCard ? 'Nome do cartão ou banco' : 'Nome do banco ou conta'),
          AppField(
            controller: _name,
            bg: trackBg,
            placeholder: 'Nubank, Inter, Itaú, PicPay…',
            capitalization: TextCapitalization.words,
            maxLength: 20,
          ),
          if (_isCard) ...[
            const SizedBox(height: Space.base),
            const FieldLabel('Bandeira'),
            Segmented<CardBrand>(
              value: _brand,
              trackColor: trackBg,
              options: const {
                CardBrand.mastercard: 'Master',
                CardBrand.visa: 'Visa',
                CardBrand.elo: 'Elo',
                CardBrand.other: 'Outra',
              },
              onChanged: (b) => setState(() => _brand = b),
            ),
          ],
          const SizedBox(height: Space.lg),
          PillButton(
            widget.card == null
                ? (_isCard ? 'Adicionar cartão' : 'Adicionar conta')
                : 'Salvar alterações',
            onTap: _valid ? _save : null,
          ),
          if (widget.card != null) ...[
            const SizedBox(height: Space.sm),
            PillButton('Excluir', kind: BtnKind.danger, onTap: _delete),
          ],
        ],
      ),
    );
  }

  void _save() {
    final s = context.storeRead;
    final trimmed = _name.text.trim();
    final err = s.saveCard(
      PayCard(
        id: widget.card?.id,
        name: trimmed,
        last4: _isCard ? (widget.card?.last4 ?? '') : '',
        color: _resolvedColor,
        brand: _isCard ? _brand : CardBrand.other,
        isCard: _isCard,
      ),
    );
    if (err != null) {
      toast(context, err, icon: LucideIcons.triangleAlert);
      return;
    }
    Navigator.pop(context);
    toast(
      context,
      widget.card == null
          ? (_isCard ? 'Cartão adicionado' : 'Conta adicionada')
          : 'Salvo com sucesso',
    );
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir "${widget.card!.name}"?',
      message:
          'Os gastos continuam no extrato, só deixam de estar ligados a esta conta.',
      action: 'Excluir',
    );
    if (!ok || !mounted) return;
    context.storeRead.deleteCard(widget.card!.id);
    Navigator.pop(context);
    toast(context, 'Conta excluída', icon: LucideIcons.trash2);
  }
}
