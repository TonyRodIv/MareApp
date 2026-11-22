import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'extrato.dart';
import 'shell.dart';

/// Linha "Contas +" da Carteira (aparece quando o usuário adiciona contas ou cartões).
class CardsStrip extends StatelessWidget {
  final bool hidden;
  const CardsStrip({super.key, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final cards = s.data.cards;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Text('Contas', style: T.body.copyWith(color: c.text)),
          const SizedBox(width: Space.sm),
          RoundIconButton(
            LucideIcons.plus,
            size: 32,
            label: 'Nova conta ou cartão',
            onTap: () => editCard(context),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: cards.isEmpty
                ? Text(
                    'Separe gastos por conta ou cartão',
                    style: T.small.copyWith(color: c.textSecondary),
                  )
                : ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: [0.0, 0.08, 0.92, 1.0],
                    ).createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      itemCount: cards.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: Space.sm),
                      itemBuilder: (_, i) => Pressable(
                        onTap: () => ShellScope.of(
                          context,
                        )?.goTo(1, filter: ExtratoFilter(cardId: cards[i].id)),
                        onLongPress: () => editCard(context, card: cards[i]),
                        child: CardChip(card: cards[i]),
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
  const CardChip({super.key, required this.card, this.width = 96});

  @override
  Widget build(BuildContext context) {
    final color = Color(card.color);
    final onColor = color.computeLuminance() > 0.5
        ? Palette.neutral800
        : Palette.neutral0;
    final hasLast4 = card.last4.trim().isNotEmpty;
    return Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Space.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            card.name.isEmpty ? 'Conta' : card.name,
            style: T.tiny.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasLast4 ? '•••${card.last4}' : 'Conta',
                  style: T.tiny.copyWith(
                    color: onColor.withValues(alpha: 0.85),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                ),
              ),
              if (hasLast4)
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
  const BrandBadge({super.key, required this.brand});
  @override
  Widget build(BuildContext context) {
    Widget box(Widget child) => Container(
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: Palette.neutral0,
        borderRadius: BorderRadius.circular(3),
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
        return const Icon(
          LucideIcons.creditCard,
          size: 14,
          color: Palette.neutral0,
        );
    }
  }
}

/// Sheet de criar/editar cartão.
Future<void> editCard(BuildContext context, {PayCard? card}) {
  return showSheet(context, builder: (ctx) => _CardForm(card: card));
}

class _CardForm extends StatefulWidget {
  final PayCard? card;
  const _CardForm({this.card});
  @override
  State<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<_CardForm> {
  late final _name = TextEditingController(text: widget.card?.name ?? '');
  late final _last4 = TextEditingController(text: widget.card?.last4 ?? '');
  late int _color = widget.card?.color ?? cardColors.first.toARGB32();
  late CardBrand _brand = widget.card?.brand ?? CardBrand.mastercard;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _last4.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _last4.dispose();
    super.dispose();
  }

  static const _bankPresets = <(String, Color)>[
    ('Nubank', Color(0xFF820AD1)),
    ('Inter', Color(0xFFFF7A00)),
    ('Itaú', Color(0xFFEC7000)),
    ('Bradesco', Color(0xFFCC092F)),
    ('C6 Bank', Color(0xFF1A1A1E)),
    ('Mercado Pago', Color(0xFF009EE3)),
    ('Santander', Color(0xFFEC0000)),
    ('PicPay', Color(0xFF11C76F)),
  ];

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_last4.text.isEmpty || _last4.text.length == 4);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final preview = PayCard(
      id: 'preview',
      name: _name.text,
      last4: _last4.text,
      color: _color,
      brand: _brand,
    );
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
            widget.card == null ? 'Nova conta ou cartão' : 'Editar conta',
            style: T.title.copyWith(color: c.text),
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Separe seus gastos por banco ou cartão no extrato.',
            style: T.small.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.base),
          Center(
            child: SpringBuilder(
              value: _color.toDouble(),
              spring: Springs.bouncy,
              builder: (_, _, v) => Transform.rotate(
                angle: (v / 1e9).clamp(-0.05, 0.05),
                child: CardChip(card: preview, width: 156),
              ),
            ),
          ),
          const SizedBox(height: Space.base),
          const FieldLabel('Bancos rápidos'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final (bName, bCol) in _bankPresets)
                ChipButton(
                  bName,
                  dot: bCol,
                  selected:
                      _name.text.trim().toLowerCase() == bName.toLowerCase(),
                  onTap: () => setState(() {
                    _name.text = bName;
                    _color = bCol.toARGB32();
                  }),
                ),
            ],
          ),
          const SizedBox(height: Space.base),
          const FieldLabel('Nome da conta ou banco'),
          AppField(
            controller: _name,
            placeholder: 'Nubank, Inter, Itaú…',
            maxLength: 20,
          ),
          const SizedBox(height: Space.md),
          const FieldLabel('Últimos 4 dígitos do cartão (opcional)'),
          AppField(
            controller: _last4,
            placeholder: 'Deixe vazio se for apenas conta',
            keyboardType: TextInputType.number,
            maxLength: 4,
            formatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          if (_last4.text.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            const FieldLabel('Bandeira'),
            Segmented<CardBrand>(
              value: _brand,
              options: const {
                CardBrand.mastercard: 'Master',
                CardBrand.visa: 'Visa',
                CardBrand.elo: 'Elo',
                CardBrand.other: 'Outra',
              },
              onChanged: (b) => setState(() => _brand = b),
            ),
          ],
          const SizedBox(height: Space.md),
          const FieldLabel('Cor'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final col in cardColors)
                Pressable(
                  semanticLabel: 'Cor',
                  onTap: () => setState(() => _color = col.toARGB32()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: col,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == col.toARGB32() ? c.text : c.border,
                        width: _color == col.toARGB32() ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          PillButton('Salvar conta', onTap: _valid ? _save : null),
          if (widget.card != null) ...[
            const SizedBox(height: Space.sm),
            PillButton('Excluir conta', kind: BtnKind.danger, onTap: _delete),
          ],
        ],
      ),
    );
  }

  void _save() {
    final s = context.storeRead;
    s.saveCard(
      PayCard(
        id: widget.card?.id,
        name: _name.text.trim(),
        last4: _last4.text,
        color: _color,
        brand: _brand,
      ),
    );
    Navigator.pop(context);
    toast(
      context,
      widget.card == null ? 'Conta adicionada' : 'Conta atualizada',
    );
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Excluir conta?',
      message:
          'Os gastos continuam no extrato, só deixam de estar ligados a esta conta.',
      action: 'Excluir',
    );
    if (!ok || !mounted) return;
    context.storeRead.deleteCard(widget.card!.id);
    Navigator.pop(context);
  }
}
