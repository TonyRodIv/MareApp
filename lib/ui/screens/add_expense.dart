import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'shell.dart';

Future<void> openAddExpense(BuildContext context) =>
    pushFluid(context, const AddExpenseFlow());
Future<void> openEditExpense(BuildContext context, Expense e) =>
    push(context, ExpenseForm(expense: e));

/// Fluxo rápido em passos (Figma 414:2887 → 414:3248 → 431:2342):
/// valor no teclado → nome com sugestões → categoria em carrossel → detalhes.
class AddExpenseFlow extends StatefulWidget {
  const AddExpenseFlow({super.key});
  @override
  State<AddExpenseFlow> createState() => _AddExpenseFlowState();
}

class _AddExpenseFlowState extends State<AddExpenseFlow> {
  final _amount = AmountController();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  int _step = 0;
  bool _forward = true;
  String _category = 'outros';
  bool _categoryTouched = false;
  Recurrence _rec = Recurrence.once;
  DateTime _date = DateTime.now();
  DateTime? _end;
  String? _cardId;
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
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  BackChevron(onTap: () => _go(-1)),
                  const Spacer(),
                  if (_step > 0 && _step < 3)
                    BlurSwitcher(
                      alignment: Alignment.centerRight,
                      child: Text(
                        fmtMoney(_amount.value),
                        key: ValueKey(_amount.value),
                        style: T.bodyStrong.copyWith(color: c.textSecondary),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const SizedBox(height: 8),
            BlurSwitcher(
              alignment: Alignment.center,
              child: Text(
                _titles[_step],
                key: ValueKey(_step),
                style: T.headline.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: easeOutExpo,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, anim) {
                  final incoming = child.key == ValueKey(_step);
                  final dir = (_forward ? 1 : -1) * (incoming ? 1 : -1);
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: Offset(0.08 * dir, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _body(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                8,
                Space.gutter,
                12,
              ),
              child: PillButton(
                _step == 3 ? 'Salvar gasto' : 'Continuar',
                onTap: _canContinue ? () => _go(1) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final c = context.c;
    switch (_step) {
      case 0:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              const Spacer(),
              AmountDisplay(cents: _amount.value, size: 64),
              const SizedBox(height: 16),
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
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
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
                cursorColor: c.accent,
                style: T.pageTitle.copyWith(color: c.text),
                placeholderStyle: T.pageTitle.copyWith(
                  color: c.textTertiary,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
              ),
              const SizedBox(height: 14),
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
        return _details(context);
    }
  }

  Widget _details(BuildContext context) {
    final c = context.c;
    final cards = context.storeRead.data.cards;
    final df = DateFormat("d 'de' MMMM", 'pt_BR');
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 24, Space.gutter, 12),
      children: [
        Reveal(
          index: 0,
          child: Row(
            children: [
              BrandLogo(
                name: _name.text.trim(),
                icon: categoryById(_category).icon,
                color: categoryById(_category).color,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.text.trim(),
                      style: T.headline.copyWith(color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      categoryById(_category).label,
                      style: T.label.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              MoneyText(_amount.value, style: T.headline),
            ],
          ),
        ),
        const SizedBox(height: 28),
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
        const SizedBox(height: 20),
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
            onTap: () =>
                pickDate(context, _date, (d) => setState(() => _date = d)),
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
                  '${k.name} •${k.last4}',
                  dot: Color(k.color),
                  selected: _cardId == k.id,
                  onTap: () => setState(() => _cardId = k.id),
                ),
            ],
          ),
        ],
      ],
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
  var current = initial;
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
                initialDateTime: min != null && initial.isBefore(min)
                    ? min
                    : initial,
                minimumDate: min == null ? null : dateOnly(min),
                maximumDate: DateTime(DateTime.now().year + 10),
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
  const ExpenseForm({super.key, required this.expense});
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
    final cat = categoryById(_e.categoryId);
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
                          child: BarTitle('Editar gasto', progress: progress),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.lg),
                    sliver: SliverList.list(
                      children: [
                        LargeTitle('Editar gasto', style: T.display),
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
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      QuickAddChips(controller: _amount, center: false),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 320),
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
                        placeholder: 'Em que você gastou?',
                        maxLength: 40,
                      ),
                      const SizedBox(height: 18),
                      const FieldLabel('Categoria'),
                      SelectField(
                        leading: Icon(
                          cat.icon,
                          color: c.tone(cat.color),
                          size: 20,
                        ),
                        value: cat.label,
                        placeholder: 'não sei ainda',
                        onTap: () async {
                          final id = await pickCategory(context, _e.categoryId);
                          if (id != null) setState(() => _e.categoryId = id);
                        },
                      ),
                      const SizedBox(height: 18),
                      const FieldLabel('Frequência do gasto'),
                      Segmented<Recurrence>(
                        value: _e.recurrence,
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
                      const SizedBox(height: 18),
                      FieldLabel(_e.isRecurring ? 'Começa em' : 'Data'),
                      SelectField(
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
                          leading: Icon(
                            LucideIcons.calendarX,
                            size: 18,
                            color: c.textSecondary,
                          ),
                          value: _e.endDate == null
                              ? null
                              : df.format(_e.endDate!),
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
                        const SizedBox(height: 18),
                        const FieldLabel('Cartão'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChipButton(
                              'Nenhum',
                              selected: _e.cardId == null,
                              onTap: () => setState(() => _e.cardId = null),
                            ),
                            for (final k in s.data.cards)
                              ChipButton(
                                k.last4.isNotEmpty
                                    ? '${k.name} •${k.last4}'
                                    : k.name,
                                dot: Color(k.color),
                                selected: _e.cardId == k.id,
                                onTap: () => setState(() => _e.cardId = k.id),
                              ),
                          ],
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
                'Salvar alterações',
                onTap: _amount.value > 0 && _name.text.trim().isNotEmpty
                    ? _save
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    _e
      ..name = _name.text.trim()
      ..cents = _amount.value;
    if (!_e.isRecurring) _e.endDate = null;
    final err = context.storeRead.updateExpense(_e);
    if (err != null) {
      toast(context, err, icon: LucideIcons.triangleAlert);
      return;
    }
    Navigator.pop(context);
    toast(context, 'Gasto atualizado');
  }
}

/// Grade de categorias num sheet.
Future<String?> pickCategory(BuildContext context, String current) {
  return showSheet<String>(
    context,
    edgeToEdge: true,
    builder: (ctx) {
      final c = ctx.c;
      return GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        padding: const EdgeInsets.fromLTRB(Space.gutter, 16, Space.gutter, 16),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: [
          for (var i = 0; i < categories.length; i++)
            Reveal(
              index: i,
              baseDelay: Duration.zero,
              child: Pressable(
                onTap: () => Navigator.pop(ctx, categories[i].id),
                child: Container(
                  padding: const EdgeInsets.all(Space.sm),
                  decoration: ShapeDecoration(
                    color: categories[i].id == current
                        ? categories[i].color.withValues(alpha: 0.16)
                        : c.cardAlt,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: categories[i].id == current
                          ? BorderSide(color: categories[i].color, width: 1.5)
                          : BorderSide.none,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconBadge(
                        categories[i].icon,
                        categories[i].color,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        categories[i].label,
                        textAlign: TextAlign.center,
                        style: T.small.copyWith(color: c.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
