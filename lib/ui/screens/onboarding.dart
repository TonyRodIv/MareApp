import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/color_engine.dart';
import '../../core/cycle.dart';
import '../../core/theme.dart';
import '../../data/drive_sync.dart';
import '../../data/store.dart';
import '../widgets/avatar_cropper.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'add_expense.dart';
import 'backup.dart';

/// Onboarding expressivo e fluido:
/// Boas-vindas → Nome → Foto de perfil → Cor destaque → Salário → Virada do ciclo → Resumo.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int _step = 0;
  bool _forward = true;
  final _name = TextEditingController();
  final _salary = AmountController();
  String? _avatarPath;
  int _startDay = 5;
  late final _dayPicker = FixedExtentScrollController(
    initialItem: _startDay - 1,
  );
  final _nameFocus = FocusNode();

  static const _steps = 8;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _salary.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _salary.dispose();
    _dayPicker.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _canNext => switch (_step) {
    1 => _name.text.trim().isNotEmpty,
    _ => true,
  };

  bool get _canSkip => _step == 2 || _step == 4 || _step == 6;

  void _go(int delta) {
    final next = (_step + delta).clamp(0, _steps - 1);
    if (next == _step) return;
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = delta > 0;
      _step = next;
    });
    if (next == 1) {
      Future.delayed(
        const Duration(milliseconds: 220),
        () => mounted ? _nameFocus.requestFocus() : null,
      );
    }
  }

  void _finish() {
    HapticFeedback.mediumImpact();
    context.storeRead.finishOnboarding(
      name: _name.text,
      salary: _salary.value,
      startDay: _startDay,
      avatarPath: _avatarPath,
    );
  }

  void _finishAndAddExpense() {
    HapticFeedback.mediumImpact();
    final nav = Navigator.of(context);
    context.storeRead.finishOnboarding(
      name: _name.text,
      salary: _salary.value,
      startDay: _startDay,
      avatarPath: _avatarPath,
    );
    nav.push<void>(FluidModalRoute(builder: (_) => const AddExpenseFlow()));
  }

  Future<void> _pickPhoto(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (x == null || !mounted) return;
      final cropped = await cropAvatarPhoto(context, File(x.path));
      if (cropped == null || !mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _avatarPath = cropped);
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Não foi possível usar essa foto',
          icon: LucideIcons.triangleAlert,
        );
      }
    }
  }

  Future<void> _openPhotoOptions() async {
    final a = await actionSheet<String>(
      context,
      title: 'Foto de perfil',
      actions: [
        const SheetAction(
          'Escolher da galeria',
          'gallery',
          icon: LucideIcons.image,
        ),
        const SheetAction('Tirar foto', 'camera', icon: LucideIcons.camera),
        if (_avatarPath != null)
          const SheetAction(
            'Remover foto',
            'remove',
            destructive: true,
            icon: LucideIcons.trash2,
          ),
      ],
    );
    if (a == 'gallery') _pickPhoto(ImageSource.gallery);
    if (a == 'camera') _pickPhoto(ImageSource.camera);
    if (a == 'remove' && mounted) setState(() => _avatarPath = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = c.bg;
    final progress = _step == 0 ? 0.0 : _step / (_steps - 1);
    final showGlow =
        _step == 0 ||
        _step == 2 ||
        _step == 3 ||
        _step == 6 ||
        _step == _steps - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(-1);
      },
      child: CupertinoPageScaffold(
        backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      child: Stack(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            opacity: showGlow ? 1.0 : 0.0,
            child: const GlowBackground(height: 460),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Column(
                children: [
                  const SizedBox(height: Space.base),
                  if (_step > 0 && _step < _steps - 1) ...[
                    _LinearProgress(progress: progress),
                    const SizedBox(height: Space.sm),
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          BackChevron(onTap: () => _go(-1)),
                          const Spacer(),
                          if (_canSkip)
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.sm,
                              ),
                              onPressed: () => _go(1),
                              child: Text(
                                'Pular',
                                style: T.bodyStrong.copyWith(color: c.primary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ] else
                    const SizedBox(height: Space.sm),
                  Expanded(
                    child: AnimatedSwitcher(
                      // Entra devagar e assenta (ease-out expo); a tela que sai some
                      // mais rápido para não competir com a que chega.
                      duration: const Duration(milliseconds: 480),
                      reverseDuration: const Duration(milliseconds: 200),
                      switchInCurve: easeOutExpo,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        final incoming = child.key == ValueKey(_step);
                        final dir = (_forward ? 1 : -1) * (incoming ? 1 : -1);
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
                        child: _stepBody(context),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    reverseDuration: const Duration(milliseconds: 140),
                    switchInCurve: easeOutExpo,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey('bar-$_step-${_avatarPath != null}'),
                      child: _bottomBar(context),
                    ),
                  ),
                  const SizedBox(height: Space.base),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    if (_step == 0) {
      final c = context.c;
      return Column(
        children: [
          PillButton(
            'Começar',
            trailingIcon: LucideIcons.arrowRight,
            onTap: () => _go(1),
          ),
          const SizedBox(height: Space.sm),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.base,
              vertical: Space.md,
            ),
            minimumSize: Size.zero,
            onPressed: () => importBackupFlow(context),
            child: Text(
              'Já uso o maré: importar backup',
              style: T.label.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }
    if (_step == _steps - 1) {
      final c = context.c;
      return Column(
        children: [
          PillButton(
            'Adicionar primeiro gasto',
            icon: LucideIcons.plus,
            onTap: _finishAndAddExpense,
          ),
          const SizedBox(height: Space.sm),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.base,
              vertical: Space.md,
            ),
            minimumSize: Size.zero,
            onPressed: _finish,
            child: Text(
              'Entrar no app',
              style: T.label.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }
    if (_step == 2) {
      final hasPhoto = _avatarPath != null;
      return Column(
        children: [
          PillButton(
            hasPhoto ? 'Continuar' : 'Escolher foto',
            icon: hasPhoto ? null : LucideIcons.camera,
            trailingIcon: hasPhoto ? LucideIcons.arrowRight : null,
            onTap: hasPhoto ? () => _go(1) : _openPhotoOptions,
          ),
          if (!hasPhoto) ...[
            const SizedBox(height: Space.sm),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.base,
                vertical: Space.md,
              ),
              minimumSize: Size.zero,
              onPressed: () => _go(1),
              child: Text(
                'Agora não',
                style: T.label.copyWith(
                  color: context.c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      );
    }
    if (_step == 6) {
      final c = context.c;
      final sync = context.sync;
      if (sync.isConnected) {
        return PillButton(
          'Continuar',
          trailingIcon: LucideIcons.arrowRight,
          onTap: () => _go(1),
        );
      }
      return Column(
        children: [
          PillButton(
            sync.isSyncing ? 'Conectando…' : 'Conectar Google Drive',
            icon: LucideIcons.cloud,
            onTap: sync.isSyncing ? null : _connectDrive,
          ),
          const SizedBox(height: Space.sm),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.base,
              vertical: Space.md,
            ),
            minimumSize: Size.zero,
            onPressed: () => _go(1),
            child: Text(
              'Agora não',
              style: T.label.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }
    return PillButton(
      'Continuar',
      trailingIcon: LucideIcons.arrowRight,
      onTap: _canNext ? () => _go(1) : null,
    );
  }

  Widget _stepBody(BuildContext context) {
    final c = context.c;
    switch (_step) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [MareWordmark(size: 24)],
            ),
            const Spacer(),
            const _WelcomeShowcase(),
            const Spacer(),
            Reveal(
              index: 1,
              child: Text(
                'Seu dinheiro no\nritmo do seu ciclo',
                textAlign: TextAlign.center,
                style: T.display.copyWith(color: c.text),
              ),
            ),
            const SizedBox(height: Space.md),
            Reveal(
              index: 2,
              child: Text(
                'Saldo livre do ciclo, caixinhas que acumulam e assinaturas sob controle',
                textAlign: TextAlign.center,
                style: T.label.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(height: Space.lg),
          ],
        );

      case 1:
        return _question(
          context,
          'Como podemos te chamar?',
          child: CupertinoTextField(
            controller: _name,
            focusNode: _nameFocus,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _canNext ? _go(1) : null,
            maxLength: 30,
            placeholder: 'Seu nome',
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
        );

      case 2:
        return _question(
          context,
          'Adicione uma foto, ${_firstName()}',
          subtitle: 'Aparece na carteira e no seu perfil',
          child: Column(
            children: [
              Pressable(
                semanticLabel: 'Escolher foto de perfil',
                onTap: _openPhotoOptions,
                child: SpringBuilder(
                  key: ValueKey(_avatarPath ?? 'empty'),
                  value: 1,
                  from: 0.84,
                  spring: Springs.bouncy,
                  builder: (_, t, _) => Transform.scale(
                    scale: t,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 148,
                          height: 148,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.primary.withValues(
                              alpha: c.isDark ? 0.14 : 0.10,
                            ),
                            border: Border.all(
                              color: c.primary.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                        ),
                        Avatar(path: _avatarPath, name: _name.text, size: 124),
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.isDark ? c.bg : Palette.neutral0,
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              _avatarPath == null
                                  ? LucideIcons.camera
                                  : LucideIcons.pencil,
                              size: 18,
                              color: c.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.base),
              Text(
                _avatarPath == null
                    ? 'Toque no círculo para escolher'
                    : 'Toque para trocar',
                style: T.small.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        );

      case 3:
        final s = context.store;
        final currentSeed =
            s.data.accentColor ?? accentThemes.first.primary.toARGB32();
        return _question(
          context,
          'Qual tema combina com você?',
          subtitle: 'Cada cor tem seu próprio gradiente atmosférico.',
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: accentThemes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 86,
            ),
            itemBuilder: (_, i) {
              final themeSpec = accentThemes[i];
              final col = themeSpec.primary;
              final selected = currentSeed == col.toARGB32();
              final (selBg, selFg) = softActionTone(col, isDark: c.isDark);
              return Pressable(
                scale: 0.96,
                semanticLabel: 'Cor ${themeSpec.name}',
                onTap: () => s.setAccentColor(col.toARGB32()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.sm,
                    vertical: Space.sm,
                  ),
                  decoration: ShapeDecoration(
                    color: selected ? selBg : c.card,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [col, themeSpec.secondaryGlow],
                          ),
                        ),
                        child: selected
                            ? Center(
                                child: Icon(
                                  LucideIcons.check,
                                  size: 16,
                                  color: onColor(col),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        themeSpec.name,
                        style: (selected ? T.smallStrong : T.small).copyWith(
                          color: selected ? selFg : c.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

      case 4:
        return Column(
          children: [
            const SizedBox(height: Space.md),
            Reveal(
              index: 0,
              child: Text(
                'Quanto entra por mês?',
                textAlign: TextAlign.center,
                style: T.pageTitle.copyWith(color: c.text),
              ),
            ),
            const SizedBox(height: Space.sm),
            Reveal(
              index: 1,
              child: Text(
                'Salário líquido, já com descontos.',
                textAlign: TextAlign.center,
                style: T.label.copyWith(color: c.textSecondary),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RoundIconButton(
                  LucideIcons.minus,
                  size: 44,
                  bg: c.cardAlt,
                  fg: c.text,
                  label: 'Diminuir 100 reais',
                  onTap: _salary.value >= 10000
                      ? () => _salary.value -= 10000
                      : null,
                ),
                const SizedBox(width: Space.base),
                Flexible(
                  child: AmountDisplay(
                    cents: _salary.value,
                    size: 44,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: Space.base),
                RoundIconButton(
                  LucideIcons.plus,
                  size: 44,
                  bg: c.cardAlt,
                  fg: c.text,
                  label: 'Aumentar 100 reais',
                  onTap: () => _salary.add(10000),
                ),
              ],
            ),
            const SizedBox(height: Space.base),
            QuickAddChips(controller: _salary),
            const Spacer(),
            Keypad(controller: _salary),
            const SizedBox(height: Space.md),
          ],
        );

      case 5:
        return _question(
          context,
          'Em que dia seu ciclo vira?',
          subtitle: 'Use o dia em que o salário cai.',
          child: Column(
            children: [
              SizedBox(
                height: 224,
                child: CupertinoPicker(
                  scrollController: _dayPicker,
                  itemExtent: 56,
                  selectionOverlay: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: Space.xl),
                      decoration: ShapeDecoration(
                        color: c.primary.withValues(
                          alpha: c.isDark ? 0.16 : 0.12,
                        ),
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(
                            Space.radiusField,
                          ),
                          side: BorderSide(
                            color: c.primary.withValues(alpha: 0.65),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  onSelectedItemChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _startDay = i + 1);
                  },
                  children: [
                    for (var d = 1; d <= 31; d++)
                      Center(
                        child: Text(
                          'Dia $d',
                          style: (d == _startDay ? T.title : T.headline)
                              .copyWith(
                                color: d == _startDay
                                    ? c.primary
                                    : c.textSecondary,
                                fontWeight: d == _startDay
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.base),
              BlurSwitcher(
                alignment: Alignment.center,
                child: Text(
                  _cycleExample(),
                  key: ValueKey(_startDay),
                  textAlign: TextAlign.center,
                  style: T.label.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
        );

      case 6:
        return _driveSyncStep(context);

      default:
        return _summary(context);
    }
  }

  Future<void> _connectDrive() async {
    final sync = context.syncRead;
    final res = await sync.connect();
    if (!mounted) return;
    if (res.ok) {
      if (_avatarPath == null &&
          sync.accountPhotoUrl != null &&
          sync.accountPhotoUrl!.isNotEmpty) {
        setState(() => _avatarPath = sync.accountPhotoUrl);
      }
      toast(context, res.message, icon: LucideIcons.check);
      // Se já havia backup no Drive e foi restaurado, o onboarding já terminou.
      if (!context.storeRead.data.onboardingDone) {
        _go(1);
      }
    } else {
      toast(context, res.message, icon: LucideIcons.triangleAlert);
    }
  }

  Widget _driveSyncStep(BuildContext context) {
    final c = context.c;
    final sync = context.sync;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        SpringBuilder(
          value: 1,
          from: 0.72,
          spring: Springs.bouncy,
          builder: (_, t, _) => Transform.scale(
            scale: t,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: c.primarySoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c.primary.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Icon(
                sync.isConnected ? LucideIcons.check : LucideIcons.cloud,
                color: c.primary,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Reveal(
          index: 1,
          child: Text(
            sync.isConnected
                ? 'Google Drive conectado'
                : 'Sincronize com o Google Drive',
            textAlign: TextAlign.center,
            style: T.pageTitle.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: Space.sm),
        Reveal(
          index: 2,
          child: Text(
            sync.isConnected
                ? '${sync.accountEmail ?? 'Conta conectada'} · seus backups serão salvos automaticamente.'
                : 'Guarde uma cópia privada na sua conta Google para nunca perder seus lançamentos ao trocar de celular.',
            textAlign: TextAlign.center,
            style: T.label.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(height: Space.lg),
        Reveal(
          index: 3,
          child: Container(
            padding: const EdgeInsets.all(Space.base),
            decoration: ShapeDecoration(
              color: c.card,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(Space.radiusCard),
                side: BorderSide(color: c.border.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 20, color: c.primary),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    'Apenas o maré acessa seu arquivo de backup numa pasta oculta do seu Drive.',
                    style: T.small.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  String _firstName() => _name.text.trim().split(' ').first;

  String _cycleExample() {
    final cy = Cycle.of(DateTime.now(), _startDay);
    final last = cy.end.subtract(const Duration(days: 1));
    return 'Ciclo atual: ${cy.start.day}/${cy.start.month} a ${last.day}/${last.month}';
  }

  Widget _summary(BuildContext context) {
    final c = context.c;
    final cy = Cycle.of(DateTime.now(), _startDay);
    final last = cy.end.subtract(const Duration(days: 1));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        SpringBuilder(
          value: 1,
          from: 0.65,
          spring: Springs.bouncy,
          builder: (_, t, _) => Transform.scale(
            scale: t,
            child: _avatarPath != null
                ? Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Avatar(path: _avatarPath, name: _name.text, size: 88),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: c.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.check,
                          color: c.onPrimary,
                          size: 16,
                        ),
                      ),
                    ],
                  )
                : Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.check, color: c.primary, size: 36),
                  ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Reveal(
          index: 1,
          child: Text(
            'Tudo pronto, ${_firstName()}',
            textAlign: TextAlign.center,
            style: T.title.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: Space.sm),
        if (_salary.value > 0) ...[
          Reveal(
            index: 2,
            child: Text(
              'Saldo livre de ${cy.label()}',
              style: T.label.copyWith(color: c.textSecondary),
            ),
          ),
          const SizedBox(height: Space.sm),
          SpringBuilder(
            value: _salary.value.toDouble(),
            from: 0,
            spring: Springs.settle,
            builder: (_, v, _) => MoneyText(
              v.round(),
              style: T.displayLg,
              color: c.primary,
            ),
          ),
          const SizedBox(height: Space.xs),
          Reveal(
            index: 3,
            child: Text(
              'Ciclo de ${cy.start.day}/${cy.start.month} a ${last.day}/${last.month}',
              style: T.label.copyWith(color: c.textSecondary),
            ),
          ),
        ] else
          Reveal(
            index: 2,
            child: Text(
              'Você pode informar o salário depois no seu perfil.',
              textAlign: TextAlign.center,
              style: T.label.copyWith(color: c.textSecondary),
            ),
          ),
        const Spacer(),
        Reveal(
          index: 4,
          child: Text(
            'Que tal já registrar seu primeiro gasto para acompanhar seu ciclo desde agora?',
            textAlign: TextAlign.center,
            style: T.small.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(height: Space.md),
      ],
    );
  }

  Widget _question(
    BuildContext context,
    String title, {
    String? subtitle,
    required Widget child,
  }) {
    final c = context.c;
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: Space.lg),
          Reveal(
            index: 0,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: T.pageTitle.copyWith(color: c.text),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Space.sm),
            Reveal(
              index: 1,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: T.label.copyWith(color: c.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: Space.xl),
          Reveal(index: 2, child: child),
        ],
      ),
    );
  }
}

/// Composição visual flutuante da tela de boas-vindas (cards preview + ícones orbitando).
class _WelcomeShowcase extends StatelessWidget {
  const _WelcomeShowcase();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        height: 248,
        width: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 224,
              height: 224,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.border.withValues(alpha: 0.45)),
              ),
            ),
            Container(
              width: 152,
              height: 152,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primary.withValues(alpha: c.isDark ? 0.12 : 0.08),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Reveal(
                index: 1,
                dy: 12,
                child: Transform.rotate(
                  angle: -0.06,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md,
                      vertical: Space.sm,
                    ),
                    decoration: ShapeDecoration(
                      color: c.primary,
                      shadows: [
                        BoxShadow(
                          color: c.primary.withValues(alpha: 0.32),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(Space.radiusField),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.piggyBank,
                          size: 16,
                          color: c.onPrimary,
                        ),
                        const SizedBox(width: Space.sm),
                        Text(
                          'Viagem · +R\$ 300',
                          style: T.smallStrong.copyWith(color: c.onPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 18,
              right: 20,
              child: Reveal(
                index: 2,
                dy: 10,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.trendingUp,
                    size: 20,
                    color: c.positive,
                  ),
                ),
              ),
            ),
            SpringBuilder(
              value: 1,
              from: 0.88,
              spring: Springs.body,
              builder: (_, t, _) => Transform.scale(
                scale: t,
                child: Container(
                  width: 272,
                  padding: const EdgeInsets.all(Space.base),
                  decoration: ShapeDecoration(
                    color: c.card,
                    shadows: [
                      BoxShadow(
                        color: Palette.neutral950.withValues(
                          alpha: c.isDark ? 0.45 : 0.08,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(Space.radiusCard),
                      side: BorderSide(color: c.border.withValues(alpha: 0.8)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MareMark(size: 24, onDark: c.isDark),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Text(
                              'Saldo livre',
                              style: T.small.copyWith(color: c.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Space.sm,
                              vertical: 2,
                            ),
                            decoration: ShapeDecoration(
                              color: c.positiveSoft,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(
                                  Space.radiusSm,
                                ),
                              ),
                            ),
                            child: Text(
                              'No ritmo',
                              style: T.smallStrong.copyWith(color: c.positive),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'R\$ 2.450,00',
                          style: T.title.copyWith(color: c.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 4,
              child: Reveal(
                index: 3,
                dy: 12,
                child: Transform.rotate(
                  angle: 0.04,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md,
                      vertical: Space.sm,
                    ),
                    decoration: ShapeDecoration(
                      color: c.cardAlt,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(Space.radiusField),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.tv, size: 16, color: c.primary),
                        const SizedBox(width: Space.sm),
                        Text(
                          'Assinaturas · R\$ 119',
                          style: T.smallStrong.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 24,
              child: Reveal(
                index: 2,
                dy: 10,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(LucideIcons.receipt, size: 18, color: c.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progresso linear fina no topo, estilo minimalista.
class _LinearProgress extends StatelessWidget {
  final double progress;
  const _LinearProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Progresso ${(progress * 100).round()}%',
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
          tween: Tween(end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 280),
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
    );
  }
}
