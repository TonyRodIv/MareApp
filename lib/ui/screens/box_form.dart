import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';

/// Criar / editar caixinha em fluxo passo a passo (igual ao de gastos):
/// valor por ciclo → nome com sugestões → ícone e cor → meta (opcional).
class BoxForm extends StatefulWidget {
  final Caixinha? box;
  const BoxForm({super.key, this.box});
  @override
  State<BoxForm> createState() => _BoxFormState();
}

class _BoxFormState extends State<BoxForm> {
  late final _name = TextEditingController(text: widget.box?.name ?? '');
  final _nameFocus = FocusNode();
  late PlanMode _mode = widget.box?.currentPlan.mode ?? PlanMode.fixed;
  late final _fixed = AmountController(_mode == PlanMode.fixed ? widget.box?.currentPlan.amount ?? 0 : 0);
  late double _percent = _mode == PlanMode.percent ? (widget.box!.currentPlan.amount / 100) : 10;
  late final _goal = AmountController(widget.box?.goalCents ?? 0);
  late String _icon = widget.box?.icon ?? 'piggy';
  late int _color = widget.box?.color ?? boxColors.first.toARGB32();

  int _step = 0;
  bool _forward = true;

  static const _steps = 4;
  static const _titles = ['Quanto entra por ciclo?', 'Qual o nome da caixinha?', 'Escolha o visual', 'Tem uma meta?'];
  static const _suggestions = ['Reserva', 'Viagem', 'Notebook', 'Carro', 'Presentes', 'Casa'];

  @override
  void initState() {
    super.initState();
    for (final l in [_name, _fixed, _goal]) {
      l.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _fixed.dispose();
    _goal.dispose();
    super.dispose();
  }

  int get _amount => _mode == PlanMode.fixed ? _fixed.value : (_percent * 100).round();

  bool get _canContinue => switch (_step) {
    0 => _amount > 0,
    1 => _name.text.trim().isNotEmpty,
    _ => true,
  };

  void _go(int d) {
    final next = _step + d;
    if (next < 0) {
      Navigator.pop(context);
      return;
    }
    if (next >= _steps) return _save();
    HapticFeedback.lightImpact();
    if (next != 1) FocusScope.of(context).unfocus();
    setState(() {
      _forward = d > 0;
      _step = next;
    });
    if (next == 1) {
      Future.delayed(const Duration(milliseconds: 160), () => mounted ? _nameFocus.requestFocus() : null);
    }
  }

  void _save() {
    final s = context.storeRead;
    final goal = _goal.value > 0 ? _goal.value : null;
    if (widget.box == null) {
      s.addBox(name: _name.text, icon: _icon, color: _color, mode: _mode, amount: _amount, goal: goal);
    } else {
      s.updateBox(widget.box!.id, name: _name.text, icon: _icon, color: _color, mode: _mode, amount: _amount, goal: goal);
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    toast(context, widget.box == null ? 'Caixinha criada' : 'Caixinha atualizada');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final salary = f.salary;
    final perCycle = _mode == PlanMode.fixed ? _fixed.value : (salary * _percent / 100).round();
    final pad = sidePadding(context, maxWidth: 640);
    final progress = (_step + 1) / _steps;

    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, Space.base, pad, 0),
              child: Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 200),
                  curve: easeOutExpo,
                  builder: (_, v, _) => FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad - Space.sm, Space.sm, pad, 0),
              child: Row(
                children: [
                  BackChevron(onTap: () => _go(-1)),
                  const Spacer(),
                  if (_step == 3)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                      onPressed: () {
                        _goal.clear();
                        _save();
                      },
                      child: Text('Sem meta', style: T.label.copyWith(color: c.primary, fontWeight: FontWeight.w600)),
                    )
                  else if (_step > 0)
                    BlurSwitcher(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _mode == PlanMode.fixed ? '${fmtMoney(perCycle)}/ciclo' : '${_percent.round()}%/ciclo',
                        key: ValueKey('$_mode-$perCycle'),
                        style: T.label.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.sm),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: BlurSwitcher(
                alignment: Alignment.center,
                child: Text(
                  _titles[_step],
                  key: ValueKey(_step),
                  textAlign: TextAlign.center,
                  style: T.title.copyWith(color: c.text),
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
                      position: Tween(begin: Offset(0.08 * dir, 0), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(key: ValueKey(_step), child: _body(context, pad, salary, perCycle)),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.base),
              child: PillButton(
                _step == _steps - 1 ? (widget.box == null ? 'Criar caixinha' : 'Salvar') : 'Continuar',
                trailingIcon: _step == _steps - 1 ? null : LucideIcons.arrowRight,
                onTap: _canContinue ? () => _go(1) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, double pad, int salary, int perCycle) {
    final c = context.c;
    final f = context.store.f;
    final free = f.freeBalance(f.current) + (widget.box == null ? 0 : f.contributionFor(widget.box!, f.current));
    final over = salary > 0 && perCycle > free;

    switch (_step) {
      case 0:
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            children: [
              const SizedBox(height: Space.base),
              Segmented<PlanMode>(
                value: _mode,
                options: const {PlanMode.fixed: 'Valor fixo', PlanMode.percent: '% do salário'},
                onChanged: (m) => setState(() => _mode = m),
              ),
              const Spacer(),
              if (_mode == PlanMode.fixed) ...[
                AmountDisplay(cents: _fixed.value, size: 48, color: c.primary),
                const SizedBox(height: Space.base),
                QuickAddChips(controller: _fixed),
              ] else ...[
                Text(
                  '${_percent.toStringAsFixed(_percent % 1 == 0 ? 0 : 1)}%',
                  style: T.display.copyWith(fontSize: 48, color: c.primary),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  salary > 0 ? '= ${fmtMoney(perCycle)} do salário atual' : 'Informe o salário no perfil para calcular',
                  style: T.label.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.lg),
                CupertinoSlider(
                  value: _percent,
                  min: 1,
                  max: 100,
                  divisions: 99,
                  activeColor: c.primary,
                  thumbColor: c.isDark ? c.onPrimary : Palette.neutral0,
                  onChanged: (v) {
                    if (v.round() != _percent.round()) HapticFeedback.selectionClick();
                    setState(() => _percent = v.roundToDouble());
                  },
                ),
              ],
              if (over) ...[
                const SizedBox(height: Space.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.triangleAlert, size: 16, color: c.accentWarm),
                    const SizedBox(width: Space.sm),
                    Flexible(
                      child: Text(
                        'Passa do saldo livre deste ciclo (${fmtMoney(free)}).',
                        style: T.small.copyWith(color: c.accentWarm),
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              if (_mode == PlanMode.fixed) Keypad(controller: _fixed),
            ],
          ),
        );

      case 1:
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
                maxLength: 30,
                placeholder: 'Viagem, reserva…',
                keyboardAppearance: c.brightness,
                cursorColor: c.primary,
                padding: const EdgeInsets.symmetric(horizontal: Space.base, vertical: Space.base),
                style: T.title.copyWith(color: c.text, fontSize: 28),
                placeholderStyle: T.title.copyWith(color: c.textTertiary, fontSize: 28),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(Space.radiusField),
                  border: Border.all(color: _name.text.trim().isNotEmpty ? c.primary : c.border, width: 1.5),
                ),
              ),
              const SizedBox(height: Space.base),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final s in _suggestions)
                    ChipButton(
                      s,
                      onTap: () {
                        _name.text = s;
                        _name.selection = TextSelection.collapsed(offset: _name.text.length);
                      },
                    ),
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        );

      case 2:
        final color = Color(_color);
        final light = Color.lerp(color, Palette.neutral0, 0.78)!;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, Space.lg, pad, Space.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: easeOutExpo,
                padding: const EdgeInsets.all(Space.base),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Space.radiusCard)),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Palette.neutral0.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(Space.radiusMd),
                      ),
                      child: Icon(boxIcons[_icon], color: light, size: 24),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name.text.trim().isEmpty ? 'Nome da caixinha' : _name.text.trim(),
                            style: T.bodyStrong.copyWith(color: Palette.neutral0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text('+${fmtMoney(perCycle)} por ciclo', style: T.small.copyWith(color: light)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.lg),
              const FieldLabel('Ícone'),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (final e in boxIcons.entries)
                    Pressable(
                      semanticLabel: e.key,
                      onTap: () => setState(() => _icon = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _icon == e.key ? color : c.card,
                          borderRadius: BorderRadius.circular(Space.radiusMd),
                          border: Border.all(color: _icon == e.key ? color : c.border),
                        ),
                        child: Icon(e.value, size: 22, color: _icon == e.key ? light : c.textSecondary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.lg),
              const FieldLabel('Cor'),
              Wrap(
                spacing: Space.md,
                runSpacing: Space.md,
                children: [
                  for (final col in boxColors)
                    Pressable(
                      semanticLabel: 'Cor',
                      onTap: () => setState(() => _color = col.toARGB32()),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == col.toARGB32() ? c.text : c.border,
                            width: _color == col.toARGB32() ? 3 : 1,
                          ),
                        ),
                        child: _color == col.toARGB32() ? const Icon(LucideIcons.check, size: 18, color: Palette.neutral0) : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );

      default:
        final cycles = perCycle > 0 && _goal.value > 0 ? (_goal.value / perCycle).ceil() : null;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            children: [
              const SizedBox(height: Space.xs),
              Text(
                cycles != null
                    ? 'Você alcança essa meta em ~$cycles ${cycles == 1 ? 'ciclo' : 'ciclos'}.'
                    : 'Opcional. Deixe zerado se não quiser definir meta.',
                textAlign: TextAlign.center,
                style: T.label.copyWith(color: c.textSecondary),
              ),
              const Spacer(),
              AmountDisplay(cents: _goal.value, size: 48, color: c.primary),
              const SizedBox(height: Space.base),
              QuickAddChips(controller: _goal),
              const Spacer(),
              Keypad(controller: _goal),
            ],
          ),
        );
    }
  }
}
