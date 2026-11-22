import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'backup.dart';
import 'cards.dart';
import 'insights.dart';
import 'shell.dart';

/// Perfil (Figma 376:6832) + configurações.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final d = s.data;
    final f = s.f;
    final pad = sidePadding(context, maxWidth: 640);
    final cy = f.current;
    final currentSeed = d.accentColor ?? accentPresets.first.$2.toARGB32();

    return Stack(
      children: [
        const GlowBackground(height: 480),
        CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            PinnedCupertinoBar(
              height: 56,
              maxWidth: 640,
              builder: (ctx, _) => const Center(child: MareWordmark(size: 20)),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, Space.base, pad, navClearance(context)),
              sliver: SliverList.list(
                children: [
                  Center(
                    child: Pressable(
                      semanticLabel: 'Editar perfil',
                      onTap: () => editProfile(context),
                      child: Avatar(path: d.avatarPath, name: d.userName, size: 96),
                    ),
                  ),
                  const SizedBox(height: Space.base),
                  Text(
                    d.userName.isEmpty ? 'Seu perfil' : d.userName,
                    textAlign: TextAlign.center,
                    style: T.title.copyWith(color: c.text),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Desde ${d.userSince} · dados salvos neste celular',
                    textAlign: TextAlign.center,
                    style: T.small.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: Space.base),
                  Center(
                    child: PillButton('Editar perfil', kind: BtnKind.ghost, expand: false, height: 44, onTap: () => editProfile(context)),
                  ),
                  const SectionHeader('Finanças'),
                  _Group(
                    children: [
                      _Row(
                        icon: LucideIcons.banknote,
                        title: 'Salário',
                        value: f.salary > 0 ? fmtMoney(f.salary, hidden: d.hideValues) : 'Não informado',
                        onTap: () => editSalary(context),
                      ),
                      _Row(
                        icon: LucideIcons.calendarSync,
                        title: 'Virada do ciclo',
                        value: 'Dia ${d.cycleStartDay}',
                        subtitle:
                            'Ciclo atual: ${cy.start.day}/${cy.start.month} a ${cy.end.subtract(const Duration(days: 1)).day}/${cy.end.subtract(const Duration(days: 1)).month}',
                        onTap: () => editCycleDay(context),
                      ),
                      _Row(
                        icon: LucideIcons.landmark,
                        title: 'Contas e cartões',
                        subtitle: 'Separe gastos por banco ou cartão',
                        value: d.cards.isEmpty ? 'Nenhuma' : '${d.cards.length}',
                        onTap: () => manageCards(context),
                      ),
                      _Row(
                        icon: LucideIcons.tv,
                        title: 'Assinaturas',
                        onTap: () => push(context, const SubscriptionsScreen()),
                      ),
                      _Row(
                        icon: LucideIcons.chartColumn,
                        title: 'Histórico de ciclos',
                        onTap: () => push(context, const HistoryScreen()),
                      ),
                    ],
                  ),
                  const SectionHeader('Aparência e privacidade'),
                  _Group(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(Space.base),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.sunMoon, size: 20, color: c.accent),
                                const SizedBox(width: Space.md),
                                Text('Tema', style: T.body.copyWith(color: c.text)),
                              ],
                            ),
                            const SizedBox(height: Space.md),
                            Segmented<ThemePref>(
                              value: d.theme,
                              options: const {ThemePref.auto: 'Automático', ThemePref.light: 'Claro', ThemePref.dark: 'Escuro'},
                              onChanged: s.setTheme,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(Space.base),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.palette, size: 20, color: c.accent),
                                const SizedBox(width: Space.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Cor destaque', style: T.body.copyWith(color: c.text)),
                                      Text(
                                        'Cor secundária ajustada no tema',
                                        style: T.small.copyWith(color: c.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.md),
                            Wrap(
                              spacing: Space.md,
                              runSpacing: Space.md,
                              children: [
                                for (final (label, col) in accentPresets)
                                  _AccentSwatch(
                                    label: label,
                                    primary: col,
                                    complementary: complementaryOf(col),
                                    selected: currentSeed == col.toARGB32(),
                                    onTap: () => s.setAccentColor(col.toARGB32()),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _Row(
                        icon: d.hideValues ? LucideIcons.eyeOff : LucideIcons.eye,
                        title: 'Ocultar valores',
                        subtitle: 'Esconde os valores na tela',
                        trailing: SpringSwitch(value: d.hideValues, label: 'Ocultar valores', onChanged: (_) => s.toggleHideValues()),
                      ),
                    ],
                  ),
                  const SectionHeader('Seus dados'),
                  _Group(
                    children: [
                      _Row(
                        icon: LucideIcons.download,
                        title: 'Exportar backup',
                        subtitle: 'Salvar cópia em JSON',
                        onTap: () => exportBackupFlow(context),
                      ),
                      _Row(
                        icon: LucideIcons.upload,
                        title: 'Importar backup',
                        subtitle: 'Restaurar cópia do maré ou FinApp',
                        onTap: () => importBackupFlow(context),
                      ),
                      _Row(icon: LucideIcons.trash2, title: 'Apagar dados do aparelho', danger: true, onTap: () => _resetAll(context)),
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

  Future<void> _resetAll(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Apagar tudo?',
      message: 'Gastos, caixinhas, cartões e perfil serão apagados deste celular. Exporte um backup antes se quiser guardar.',
      action: 'Apagar tudo',
    );
    if (!ok || !context.mounted) return;
    final ok2 = await confirm(context, title: 'Tem certeza?', message: 'Não dá para desfazer.', action: 'Sim, apagar');
    if (!ok2 || !context.mounted) return;
    context.storeRead.resetAll();
  }
}

class _AccentSwatch extends StatelessWidget {
  final String label;
  final Color primary;
  final Color complementary;
  final bool selected;
  final VoidCallback onTap;
  const _AccentSwatch({
    required this.label,
    required this.primary,
    required this.complementary,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      semanticLabel: 'Cor $label',
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? c.text : c.border, width: selected ? 2.5 : 1),
        ),
        child: ClipOval(
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: primary)),
              Positioned(
                right: 0,
                bottom: 0,
                width: 18,
                height: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: complementary,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
                  ),
                ),
              ),
              if (selected)
                const Center(child: Icon(LucideIcons.check, size: 16, color: Palette.neutral0)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grupo de opções espaçado (estilo Material Expressive com cores iOS):
/// cada item tem seu próprio container suave com cantos externos 22 e internos 6.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final n = children.length;
    return Column(
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: Space.xs),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? 22 : 8),
                bottom: Radius.circular(i == n - 1 ? 22 : 8),
              ),
              border: Border.all(color: c.border.withValues(alpha: c.isDark ? 0.45 : 0.65)),
            ),
            clipBehavior: Clip.antiAlias,
            child: children[i],
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  const _Row({required this.icon, required this.title, this.subtitle, this.value, this.trailing, this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = danger ? c.negative : c.text;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.base, vertical: Space.base),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: danger ? c.negativeSoft : c.primarySoft,
              borderRadius: BorderRadius.circular(Space.radiusMd),
            ),
            child: Icon(icon, size: 18, color: danger ? c.negative : c.accent),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.body.copyWith(color: color, fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  const SizedBox(height: Space.xxs),
                  Text(subtitle!, style: T.small.copyWith(color: c.textSecondary)),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: Space.md),
            Text(value!, style: T.label.copyWith(color: c.textSecondary)),
          ],
          ?trailing,
          if (onTap != null && trailing == null) ...[
            const SizedBox(width: Space.xs),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textTertiary),
          ],
        ],
      ),
    );
    return onTap == null ? row : Pressable(scale: 0.99, onTap: onTap, child: row);
  }
}

// ── Sheets ──────────────────────────────────────────────────

Future<void> editSalary(BuildContext context) {
  final s = context.storeRead;
  final ctl = AmountController(s.f.salary);
  return showSheet(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        ctl.addListener(() => set(() {}));
        final c = ctx.c;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 12, Space.gutter, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Salário', style: T.title.copyWith(color: c.text, fontSize: 24)),
              Text(
                'Valor líquido que entra por ciclo. Vale a partir deste ciclo; os anteriores mantêm o valor antigo.',
                style: T.small.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 20),
              Center(child: AmountDisplay(cents: ctl.value, size: 48)),
              const SizedBox(height: 16),
              Keypad(controller: ctl),
              const SizedBox(height: 12),
              PillButton(
                'Salvar salário',
                onTap: () {
                  s.setSalary(ctl.value);
                  Navigator.pop(ctx);
                  toast(context, 'Salário atualizado');
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> editCycleDay(BuildContext context) {
  final s = context.storeRead;
  var day = s.data.cycleStartDay;
  return showSheet(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final c = ctx.c;
        final cy = Cycle.of(DateTime.now(), day);
        final last = cy.end.subtract(const Duration(days: 1));
        return Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 12, Space.gutter, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Virada do ciclo', style: T.title.copyWith(color: c.text, fontSize: 24)),
              Text(
                'Use o dia em que o salário cai. Em meses mais curtos, a virada acontece no último dia.',
                style: T.small.copyWith(color: c.textSecondary),
              ),
              SizedBox(
                height: 180,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: day - 1),
                  itemExtent: 44,
                  onSelectedItemChanged: (i) {
                    HapticFeedback.selectionClick();
                    set(() => day = i + 1);
                  },
                  children: [
                    for (var d = 1; d <= 31; d++)
                      Center(
                        child: Text(
                          'Dia $d',
                          style: T.headline.copyWith(color: c.text, fontWeight: FontWeight.w400),
                        ),
                      ),
                  ],
                ),
              ),
              Center(
                child: BlurSwitcher(
                  alignment: Alignment.center,
                  child: Text(
                    'Ciclo atual: ${cy.start.day}/${cy.start.month} a ${last.day}/${last.month}',
                    key: ValueKey(day),
                    style: T.label.copyWith(color: c.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PillButton(
                'Salvar',
                onTap: () {
                  s.setCycleStartDay(day);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> manageCards(BuildContext context) {
  return showSheet(
    context,
    builder: (ctx) {
      final c = ctx.c;
      final s = ctx.store;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 12, Space.gutter, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contas e cartões', style: T.title.copyWith(color: c.text, fontSize: 24)),
            Text(
              'Adicione bancos ou cartões para filtrar seus gastos no extrato. Segure um item na Carteira para editar.',
              style: T.small.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 16),
            for (final k in s.data.cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Pressable(
                  onTap: () => editCard(ctx, card: k),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: [
                        CardChip(card: k, width: 76),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(k.name, style: T.bodyStrong.copyWith(color: c.text)),
                              if (k.last4.isNotEmpty)
                                Text('Final ${k.last4}', style: T.small.copyWith(color: c.textSecondary)),
                            ],
                          ),
                        ),
                        Icon(LucideIcons.pencil, size: 18, color: c.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            PillButton('Adicionar conta ou cartão', icon: LucideIcons.plus, onTap: () => editCard(ctx)),
          ],
        ),
      );
    },
  );
}

Future<void> editProfile(BuildContext context) => showSheet(context, builder: (_) => const _ProfileForm());

class _ProfileForm extends StatefulWidget {
  const _ProfileForm();
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _name = TextEditingController(text: context.storeRead.data.userName);
  late String? _avatar = context.storeRead.data.avatarPath;
  bool _removed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 512, maxHeight: 512, imageQuality: 82);
      if (x == null) return;
      // Copia para a pasta do app: o arquivo temporário do picker pode sumir.
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(x.path).copy(dest.path);
      setState(() {
        _avatar = dest.path;
        _removed = false;
      });
    } catch (_) {
      if (mounted) toast(context, 'Não foi possível usar essa foto', icon: LucideIcons.triangleAlert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 12, Space.gutter, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Editar perfil', style: T.title.copyWith(color: c.text, fontSize: 24)),
          const SizedBox(height: 20),
          Center(
            child: Pressable(
              onTap: () async {
                final a = await actionSheet<String>(
                  context,
                  actions: [
                    const SheetAction('Escolher da galeria', 'gallery', icon: LucideIcons.image),
                    const SheetAction('Tirar foto', 'camera', icon: LucideIcons.camera),
                    if (_avatar != null) const SheetAction('Remover foto', 'remove', destructive: true, icon: LucideIcons.trash2),
                  ],
                );
                if (a == 'gallery') _pick(ImageSource.gallery);
                if (a == 'camera') _pick(ImageSource.camera);
                if (a == 'remove') {
                  setState(() {
                    _avatar = null;
                    _removed = true;
                  });
                }
              },
              child: Stack(
                children: [
                  Avatar(path: _avatar, name: _name.text, size: 96),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg, width: 2),
                      ),
                      child: Icon(LucideIcons.camera, size: 16, color: c.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const FieldLabel('Nome'),
          AppField(
            controller: _name,
            placeholder: 'Seu nome',
            capitalization: TextCapitalization.words,
            maxLength: 30,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          PillButton(
            'Salvar',
            onTap: () {
              context.storeRead.setProfile(name: _name.text, avatarPath: _removed ? null : _avatar, clearAvatar: _removed);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
