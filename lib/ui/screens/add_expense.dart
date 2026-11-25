import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/brands.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'shell.dart';

Future<void> openAddExpense(
  BuildContext context, {
  String? initialCategoryId,
  String? initialCardId,
}) => pushFluid(
  context,
  AddExpenseFlow(
    initialCategoryId: initialCategoryId,
    initialCardId: initialCardId,
  ),
);
Future<void> openEditExpense(
  BuildContext context,
  Expense e, {
  void Function(String newId)? onSplit,
}) => showIosSheet<void>(
  context,
  builder: (_) => ExpenseForm(expense: e, onSplit: onSplit),
);

/// Fluxo rápido em passos (Figma 414:2887 → 414:3248 → 431:2342):
/// valor no teclado → nome com sugestões → categoria em carrossel → detalhes.
class AddExpenseFlow extends StatefulWidget {
  final String? initialCategoryId;
  final String? initialCardId;
  const AddExpenseFlow({
    super.key,
    this.initialCategoryId,
    this.initialCardId,
  });
  @override
  State<AddExpenseFlow> createState() => _AddExpenseFlowState();
}

class _AddExpenseFlowState extends State<AddExpenseFlow> {
  final _amount = AmountController();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _detailsScroll = ValueNotifier<double>(0);
  int _step = 0;
  bool _forward = true;
  late String _category = widget.initialCategoryId ?? 'outros';
  late bool _categoryTouched = widget.initialCategoryId != null;
  Recurrence _rec = Recurrence.once;
  DateTime _date = DateTime.now();
  DateTime? _end;
  late String? _cardId = widget.initialCardId;
  late final PageController _catPage = PageController(viewportFraction: 0.56);

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    _name.addListener(_onName);
  }

  void _onName() {
    // Sugere a categoria enquanto digita, até o usuário escolher uma.
    if (!_categoryTouched) {
      final remembered = context.storeRead
          .recentNames(limit: 50)
          .where((e) => e.key.toLowerCase() == _name.text.trim().toLowerCase())
          .firstOrNull;
      final g = remembered != null
          ? categoryById(remembered.value)
          : guessCategory(_name.text);
      _category = g?.id ?? 'outros';
    }
    setState(() {});
  }

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    _nameFocus.dispose();
    _detailsScroll.dispose();
    _catPage.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    0 => _amount.value > 0,
    1 => _name.text.trim().isNotEmpty,
    _ => true,
  };

  void _go(int d) {
    final next = _step + d;
    if (next < 0) {
      Navigator.pop(context);
      return;
    }
    if (next > 3) return _save();
    HapticFeedback.lightImpact();
    if (next != 1) FocusScope.of(context).unfocus();
    setState(() {
      _forward = d > 0;
      _step = next;
      if (next != 3) _detailsScroll.value = 0;
    });
    if (next == 1) {
      Future.delayed(
        const Duration(milliseconds: 160),
        () => mounted ? _nameFocus.requestFocus() : null,
      );
    }
    if (next == 2) {
      final idx = categories.indexWhere((c) => c.id == _category);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_catPage.hasClients) _catPage.jumpToPage(idx < 0 ? 0 : idx);
      });
    }
  }

  void _save() {
    final s = context.storeRead;
    final err = s.addExpense(
      Expense(
        name: _name.text.trim(),
        cents: _amount.value,
        categoryId: _category,
        cardId: _cardId,
        date: _rec == Recurrence.monthly ? s.f.cycleOf(_date).start : _date,
        recurrence: _rec,
        endDate: _rec == Recurrence.monthly ? _end : null,
      ),
    );
    if (err != null) {
      toast(context, err, icon: LucideIcons.triangleAlert);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    toast(context, 'Gasto salvo');
  }

  static const _titles = [
    'Quanto você gastou?',
    'Em que você gastou?',
    'Qual categoria?',
    'Quase lá',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pad = sidePadding(context, maxWidth: 640);
    final progress = (_step + 1) / 4;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(-1);
      },
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, Space.base, pad, 0),
              child: Container(
                height: 4,
                width: double.infinity,
                decoration: ShapeDecoration(
                  color: c.border,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 200),
                  curve: easeOutExpo,
                  builder: (_, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      decoration: ShapeDecoration(
                        color: c.primary,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 480),
                        reverseDuration: const Duration(milliseconds: 200),
                        switchInCurve: easeOutExpo,
                        switchOutCurve: Curves.easeInCubic,
                        layoutBuilder: (cur, prev) => Stack(
                          fit: StackFit.expand,
                          children: [...prev, if (cur != null) cur],
                        ),
                        transitionBuilder: (child, anim) {
                          final incoming = child.key == ValueKey(_step);
                          final dir =
                              (_forward ? 1 : -1) * (incoming ? 1 : -1);
                          return AnimatedBuilder(
                            animation: anim,
                            child: child,
                            builder: (_, ch) {
                              final t = anim.value;
                              return Opacity(
                                opacity: clampOpacity(t * 1.4),
                                child: Transform.translate(
                                  offset: Offset(64.0 * dir * (1 - t), 0),
                                  child: Transform.scale(
                                    scale: 0.96 + 0.04 * t,
                                    child: ch,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _step == 3
                              ? _body(context, pad)
                              : Padding(
                                  padding: const EdgeInsets.only(top: 56),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: pad,
                                        ),
                                        child: Text(
                                          _titles[_step],
                                          textAlign: TextAlign.center,
                                          style: T.title.copyWith(
                                            color: c.text,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: _body(context, pad)),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  if (_step == 3) ...[
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 116,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _detailsScroll,
                          builder: (_, px, _) {
                            final t = (px / 36.0).clamp(0.0, 1.0);
                            if (t <= 0.005) return const SizedBox.shrink();
                            final eased = Curves.easeOutCubic.transform(t);
                            return ProgressiveBlur(
                              direction: AxisDirection.down,
                              maxSigma: 18 * eased,
                              tint: c.bg,
                              tintOpacity: (c.isDark ? 0.86 : 0.88) * eased,
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 104,
                      child: IgnorePointer(
                        child: ProgressiveBlur(
                          direction: AxisDirection.up,
                          maxSigma: 18,
                          tint: c.bg,
                          tintOpacity: c.isDark ? 0.88 : 0.90,
                        ),
                      ),
                    ),
                    Positioned(
                      left: pad,
                      right: pad,
                      bottom: Space.base,
                      child: PillButton(
                        'Salvar gasto',
                        onTap: _canContinue ? () => _go(1) : null,
                      ),
                    ),
                  ],
                  Positioned(
                    left: pad - Space.sm,
                    right: pad,
                    top: Space.sm,
                    child: Row(
                      children: [
                        BackChevron(onTap: () => _go(-1)),
                        Expanded(
                          child: BlurSwitcher(
                            alignment: _step == 3
                                ? Alignment.center
                                : Alignment.centerRight,
                            child: _step == 3
                                ? Text(
                                    'Quase lá',
                                    key: const ValueKey('quase-la-title'),
                                    textAlign: TextAlign.center,
                                    style: T.headline.copyWith(
                                      color: c.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : (_step > 0
                                      ? Text(
                                          fmtMoney(_amount.value),
                                          key: ValueKey(_amount.value),
                                          style: T.label.copyWith(
                                            color: c.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      : const SizedBox.shrink()),
                          ),
                        ),
                        if (_step == 3) const SizedBox(width: 44),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_step != 3)
              Padding(
                padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.base),
                child: PillButton(
                  'Continuar',
                  trailingIcon: LucideIcons.arrowRight,
                  onTap: _canContinue ? () => _go(1) : null,
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _body(BuildContext context, double pad) {
    final c = context.c;
    switch (_step) {
      case 0:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            children: [
              const Spacer(),
              AmountDisplay(cents: _amount.value, size: 56),
              const SizedBox(height: Space.base),
              QuickAddChips(controller: _amount),
              const Spacer(),
              Keypad(controller: _amount),
            ],
          ),
        );
      case 1:
        final recents = context.storeRead.recentNames();
        final suggestions = recents.isNotEmpty
            ? recents.map((e) => e.key).take(6).toList()
            : const ['Mercado', 'Uber', 'iFood', 'Farmácia', 'Lazer'];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            children: [
              const Spacer(),
              CupertinoTextField(
                controller: _name,
                focusNode: _nameFocus,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _canContinue ? _go(1) : null,
                maxLength: 40,
                placeholder: 'Mercado, uber…',
                keyboardAppearance: c.brightness,
                cursorColor: c.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.base,
                  vertical: Space.base,
                ),
                style: T.pageTitle.copyWith(color: c.text),
                placeholderStyle: T.pageTitle.copyWith(
                  color: c.textTertiary,
                ),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(Space.radiusField),
                ),
              ),
              const SizedBox(height: Space.base),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in suggestions)
                    ChipButton(
                      s,
                      onTap: () {
                        _name.text = s;
                        _name.selection = TextSelection.collapsed(
                          offset: _name.text.length,
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                opacity: _name.text.trim().isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: BlurSwitcher(
                  alignment: Alignment.center,
                  child: Row(
                    key: ValueKey(_category),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        categoryById(_category).icon,
                        size: 16,
                        color: c.tone(categoryById(_category).color),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Categoria sugerida: ${categoryById(_category).label}',
                        style: T.small.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        );
      case 2:
        return Column(
          children: [
            const Spacer(),
            SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _catPage,
                itemCount: categories.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _category = categories[i].id;
                    _categoryTouched = true;
                  });
                },
                itemBuilder: (_, i) => AnimatedBuilder(
                  animation: _catPage,
                  builder: (_, _) {
                    final page =
                        _catPage.hasClients && _catPage.position.haveDimensions
                        ? _catPage.page ?? 0
                        : categories
                              .indexWhere((x) => x.id == _category)
                              .toDouble();
                    final d = (page - i).abs().clamp(0.0, 1.0);
                    final cat = categories[i];
                    return Transform.scale(
                      scale: 1 - 0.16 * d,
                      child: Opacity(
                        opacity: 1 - 0.5 * d,
                        child: Pressable(
                          onTap: () => _catPage.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 400),
                            curve: easeOutExpo,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: ShapeDecoration(
                              color: Color.lerp(
                                cat.color.withValues(
                                  alpha: c.isDark ? 0.22 : 0.16,
                                ),
                                c.card,
                                d,
                              ),
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 56,
                                  color: Color.lerp(
                                    c.tone(cat.color),
                                    c.textTertiary,
                                    d,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  cat.label,
                                  style: T.headline.copyWith(color: c.text),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Deslize para trocar',
              style: T.small.copyWith(color: c.textTertiary),
            ),
            const Spacer(),
          ],
        );
      default:
        return _details(context, pad);
    }
  }

  Widget _details(BuildContext context, double pad) {
    final c = context.c;
    final s = context.storeRead;
    final cards = s.data.cards;
    final selectedCard = s.card(_cardId);
    final cat = categoryById(_category);
    final df = DateFormat("d 'de' MMMM", 'pt_BR');
    final dfFull = DateFormat('dd/MM/yyyy', 'pt_BR');
    final cycleLabel = s.f.cycleOf(_date).label();
    final dateText = sameDay(_date, DateTime.now())
        ? 'Hoje · ${dfFull.format(_date)}'
        : dfFull.format(_date);
    final freqText = _rec == Recurrence.once
        ? 'Único'
        : (_end == null
              ? 'Todo ciclo'
              : 'Até ${DateFormat('MM/yy').format(_end!)}');

    Widget receiptRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: T.small.copyWith(color: c.textSecondary)),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: T.labelStrong.copyWith(color: c.text),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
          final px = n.metrics.pixels;
          if ((px - _detailsScroll.value).abs() > 0.5) {
            _detailsScroll.value = px;
          }
        }
        return false;
      },
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(pad, 64, pad, 108),
        children: [
        // Cartão de prévia do gasto (mini visualização estilo recibo/detalhe)
        Reveal(
          index: 0,
          child: AppCard(
            padding: const EdgeInsets.all(Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BrandLogo(
                      name: _name.text.trim(),
                      icon: cat.icon,
                      color: cat.color,
                      size: 46,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name.text.trim(),
                            style: T.bodyStrong.copyWith(color: c.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cat.label,
                            style: T.small.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.md),
                  child: Container(
                    height: 1,
                    color: c.border.withValues(alpha: 0.35),
                  ),
                ),
                receiptRow('Data', dateText),
                receiptRow('Frequência', freqText),
                receiptRow('Ciclo', cycleLabel),
                receiptRow(
                  selectedCard?.isCard == true ? 'Cartão' : 'Conta',
                  selectedCard == null
                      ? 'Sem conta'
                      : (selectedCard.last4.isNotEmpty
                            ? '${selectedCard.name} ••${selectedCard.last4}'
                            : selectedCard.name),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.md),
                  child: Container(
                    height: 1,
                    color: c.border.withValues(alpha: 0.35),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Total',
                      style: T.bodyStrong.copyWith(color: c.text),
                    ),
                    const Spacer(),
                    MoneyText(_amount.value, style: T.title),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Reveal(index: 1, child: const FieldLabel('Frequência do gasto')),
        Reveal(
          index: 1,
          child: Segmented<Recurrence>(
            value: _rec,
            options: const {
              Recurrence.once: 'Único',
              Recurrence.monthly: 'Recorrente',
            },
            onChanged: (r) => setState(() => _rec = r),
          ),
        ),
        const SizedBox(height: 8),
        BlurSwitcher(
          child: Text(
            _rec == Recurrence.once
                ? 'Conta só no ciclo da data do gasto.'
                : 'Repete todo ciclo até você encerrar.',
            key: ValueKey(_rec),
            style: T.small.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(height: Space.base),
        Reveal(
          index: 2,
          child: FieldLabel(_rec == Recurrence.once ? 'Quando' : 'Começa em'),
        ),
        Reveal(
          index: 2,
          child: SelectField(
            leading: Icon(
              LucideIcons.calendar,
              size: 18,
              color: c.textSecondary,
            ),
            value: sameDay(_date, DateTime.now()) ? 'Hoje' : df.format(_date),
            placeholder: 'Hoje',
            onTap: () => pickDate(
              context,
              _date,
              (d) => setState(() {
                _date = d;
                if (_end != null && dateOnly(_end!).isBefore(dateOnly(d))) {
                  _end = d;
                }
              }),
            ),
          ),
        ),
        if (_rec == Recurrence.monthly) ...[
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
              _end ?? DateTime.now().add(const Duration(days: 90)),
              (d) => setState(() => _end = d),
              onClear: () => setState(() => _end = null),
              min: _date,
            ),
          ),
        ],
        if (cards.isNotEmpty) ...[
          const SizedBox(height: 20),
          const FieldLabel('Cartão (opcional)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChipButton(
                'Nenhum',
                selected: _cardId == null,
                onTap: () => setState(() => _cardId = null),
              ),
              for (final k in cards)
                ChipButton(
                  k.last4.isNotEmpty ? '${k.name} •${k.last4}' : k.name,
                  dot: Color(k.color),
                  selected: _cardId == k.id,
                  onTap: () => setState(() => _cardId = k.id),
                ),
            ],
          ),
        ],
      ],
      ),
    );
  }
}

/// Picker de data nativo (Cupertino) num modal compacto colado nas bordas.
Future<void> pickDate(
  BuildContext context,
  DateTime initial,
  ValueChanged<DateTime> onPick, {
  VoidCallback? onClear,
  DateTime? min,
}) {
  final maxDate = DateTime(DateTime.now().year + 10);
  final minDate = min == null ? null : dateOnly(min);
  var current = initial;
  if (minDate != null && current.isBefore(minDate)) current = minDate;
  if (current.isAfter(maxDate)) current = maxDate;
  return showSheet<void>(
    context,
    builder: (ctx) {
      final c = ctx.c;
      return SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Row(
                children: [
                  if (onClear != null)
                    CupertinoButton(
                      onPressed: () {
                        onClear();
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        'Remover',
                        style: T.body.copyWith(color: c.negative),
                      ),
                    ),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () {
                      onPick(current);
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Pronto',
                      style: T.bodyStrong.copyWith(color: c.accent),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: current,
                minimumDate: minDate,
                maximumDate: maxDate,
                onDateTimeChanged: (d) => current = d,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Formulário completo (Figma 376:9188): usado para editar um gasto.
class ExpenseForm extends StatefulWidget {
  final Expense expense;
  final void Function(String newId)? onSplit;
  const ExpenseForm({super.key, required this.expense, this.onSplit});
  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  late final Expense _e = widget.expense.copy();
  late final _amount = AmountController(_e.cents);
  late final _name = TextEditingController(text: _e.name);
  bool _typing = false;

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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final df = DateFormat("d 'de' MMMM 'de' y", 'pt_BR');
    final fieldBg = c.isDark ? c.cardAlt : c.surfaceLow;
    final chipBg = c.isDark
        ? c.surfaceHigh
        : Palette.neutral100.withValues(alpha: 0.7);

    return SheetBody(
      bottom: PillButton(
        'Salvar alterações',
        onTap: _amount.value > 0 && _name.text.trim().isNotEmpty ? _save : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Editar gasto',
                  style: T.title.copyWith(color: c.text),
                ),
              ),
              RoundIconButton(
                LucideIcons.x,
                size: 36,
                bg: fieldBg,
                label: 'Fechar',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Space.base),
          Pressable(
            onTap: () => setState(() => _typing = !_typing),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.base),
              decoration: ShapeDecoration(
                color: fieldBg,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AmountDisplay(
                          cents: _amount.value,
                          size: 38,
                          center: false,
                        ),
                      ),
                      Icon(
                        _typing ? LucideIcons.chevronUp : LucideIcons.pencil,
                        size: 18,
                        color: c.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  QuickAddChips(
                    controller: _amount,
                    center: false,
                    chipBg: chipBg,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: easeOutExpo,
            child: _typing
                ? Padding(
                    padding: const EdgeInsets.only(top: Space.md),
                    child: Keypad(
                      controller: _amount,
                      keyColor: fieldBg,
                      keyHeight: 54,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: Space.base),
          const FieldLabel('Nome'),
          AppField(
            controller: _name,
            placeholder: 'Em que você gastou?',
            bg: fieldBg,
            maxLength: 40,
          ),
          const SizedBox(height: Space.base),
          const FieldLabel('Categoria'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in categories)
                () {
                  final selected = item.id == _e.categoryId;
                  final tone = c.tone(item.color);
                  return Pressable(
                    scale: 0.96,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _e.categoryId = item.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: ShapeDecoration(
                        color: selected
                            ? item.color.withValues(
                                alpha: c.isDark ? 0.24 : 0.16,
                              )
                            : fieldBg,
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 15,
                            color: selected ? tone : c.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.label,
                            style: (selected ? T.smallStrong : T.small)
                                .copyWith(color: selected ? tone : c.text),
                          ),
                        ],
                      ),
                    ),
                  );
                }(),
            ],
          ),
          const SizedBox(height: Space.base),
          const FieldLabel('Frequência do gasto'),
          Segmented<Recurrence>(
            value: _e.recurrence,
            trackColor: fieldBg,
            options: const {
              Recurrence.once: 'Único',
              Recurrence.monthly: 'Recorrente',
            },
            onChanged: (r) => setState(() => _e.recurrence = r),
          ),
          const SizedBox(height: 8),
          Text(
            _e.isRecurring
                ? 'Repete todo ciclo. Se mudar o valor, os meses anteriores continuam com o valor antigo.'
                : 'Conta só no ciclo da data do gasto.',
            style: T.small.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.base),
          FieldLabel(_e.isRecurring ? 'Começa em' : 'Data'),
          SelectField(
            bg: fieldBg,
            leading: Icon(
              LucideIcons.calendar,
              size: 18,
              color: c.textSecondary,
            ),
            value: df.format(_e.date),
            placeholder: '',
            onTap: () => pickDate(
              context,
              _e.date,
              (d) => setState(() {
                _e.date = d;
                if (_e.endDate != null &&
                    dateOnly(_e.endDate!).isBefore(dateOnly(d))) {
                  _e.endDate = d;
                }
              }),
            ),
          ),
          if (_e.isRecurring) ...[
            const SizedBox(height: 14),
            const FieldLabel('Termina em (opcional)'),
            SelectField(
              bg: fieldBg,
              leading: Icon(
                LucideIcons.calendarX,
                size: 18,
                color: c.textSecondary,
              ),
              value: _e.endDate == null ? null : df.format(_e.endDate!),
              placeholder: 'Sem data final',
              onTap: () => pickDate(
                context,
                _e.endDate ?? _e.date,
                (d) => setState(() => _e.endDate = d),
                onClear: () => setState(() => _e.endDate = null),
                min: _e.date,
              ),
            ),
          ],
          if (s.data.cards.isNotEmpty) ...[
            const SizedBox(height: Space.base),
            const FieldLabel('Conta ou cartão'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChipButton(
                  'Nenhum',
                  bg: fieldBg,
                  selected: _e.cardId == null,
                  onTap: () => setState(() => _e.cardId = null),
                ),
                for (final k in s.data.cards)
                  ChipButton(
                    k.last4.isNotEmpty ? '${k.name} •${k.last4}' : k.name,
                    dot: Color(k.color),
                    bg: fieldBg,
                    selected: _e.cardId == k.id,
                    onTap: () => setState(() => _e.cardId = k.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _save() {
    _e
      ..name = _name.text.trim()
      ..cents = _amount.value;
    if (!_e.isRecurring) _e.endDate = null;
    final err = context.storeRead.updateExpense(
      _e,
      onSplit: widget.onSplit,
    );
    if (err != null) {
      toast(context, err, icon: LucideIcons.triangleAlert);
      return;
    }
    Navigator.pop(context);
    toast(context, 'Gasto atualizado');
  }
}

/// Seletor moderno de categoria com busca instantânea por nome ou palavra-chave
/// e grade compacta de 2 colunas.
Future<String?> pickCategory(BuildContext context, String current) {
  final searchCtrl = TextEditingController();
  return showIosSheet<String>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final c = ctx.c;
        final itemBg = c.isDark ? c.cardAlt : c.surfaceLow;
        final q = foldText(searchCtrl.text.trim());
        final guessed = q.isEmpty ? null : guessCategory(searchCtrl.text);
        final list = q.isEmpty
            ? categories
            : <Category>[
                if (guessed != null) guessed,
                for (final cat in categories)
                  if (cat.id != guessed?.id &&
                      (foldText(cat.label).contains(q) ||
                          cat.keywords.any((kw) => foldText(kw).contains(q))))
                    cat,
              ];
        final shown = list.isEmpty ? categories : list;

        return SheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Categoria',
                      style: T.title.copyWith(color: c.text),
                    ),
                  ),
                  RoundIconButton(
                    LucideIcons.x,
                    size: 36,
                    bg: itemBg,
                    label: 'Fechar',
                    onTap: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              AppField(
                controller: searchCtrl,
                placeholder: 'Buscar categoria ou exemplo (ex.: mercado, luz)…',
                bg: itemBg,
                onChanged: (_) => set(() {}),
                prefix: Icon(
                  LucideIcons.search,
                  size: 18,
                  color: c.textSecondary,
                ),
                suffix: searchCtrl.text.isEmpty
                    ? null
                    : Pressable(
                        onTap: () {
                          searchCtrl.clear();
                          set(() {});
                        },
                        child: Icon(
                          LucideIcons.x,
                          size: 18,
                          color: c.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(height: Space.base),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: shown.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 52,
                ),
                itemBuilder: (_, i) {
                  final cat = shown[i];
                  final selected = cat.id == current;
                  final tone = c.tone(cat.color);
                  return Pressable(
                    scale: 0.97,
                    onTap: () => Navigator.pop(ctx, cat.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: ShapeDecoration(
                        color: selected
                            ? cat.color.withValues(
                                alpha: c.isDark ? 0.24 : 0.16,
                              )
                            : itemBg,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cat.color.withValues(
                                alpha: c.isDark ? 0.26 : 0.16,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(cat.icon, size: 16, color: tone),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat.label,
                              style: (selected ? T.labelStrong : T.label)
                                  .copyWith(color: selected ? tone : c.text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selected)
                            Icon(LucideIcons.check, size: 16, color: tone),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
