import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/drive_sync.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'backup.dart';
import 'box_form.dart';
import 'cards.dart';
import 'insights.dart';
import 'shell.dart';
import 'sync.dart';

/// Perfil redesenhado: cabeçalho com status de sincronização no Drive, botões
/// lado a lado (Editar Perfil / Configurações) e grade bento de Finanças.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final sync = context.sync;
    final d = s.data;
    final f = s.f;
    final hidden = d.hideValues;
    final pad = sidePadding(context, maxWidth: 640);
    final cy = f.current;
    final lastDay = cy.end.subtract(const Duration(days: 1));
    final subs = f.subscriptions(cy);
    final subsTotal = subs.fold<int>(0, (t, e) => t + e.cents);
    final byCat = f.byCategory(cy);
    final catTotal = byCat.fold<int>(0, (t, e) => t + e.value);
    final topCat = byCat.isEmpty ? null : byCat.first;
    final activeCycles = [
      for (final item in f.lastCycles(12))
        if (f.salaryFor(item) > 0 || f.expensesTotal(item) > 0) item,
    ].length;

    final syncLabel = !sync.isConnected
        ? 'Salvo só neste celular · Conectar Drive'
        : sync.isSyncing
        ? 'Sincronizando com o Drive…'
        : sync.pendingConflict != null
        ? 'Conflito no Drive · Resolver'
        : 'Sincronizado com o Drive';
    final syncIcon = sync.isConnected ? LucideIcons.cloud : LucideIcons.cloudOff;

    return Stack(
      children: [
        const GlowBackground(height: 480),
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            PinnedCupertinoBar(
              height: 56,
              maxWidth: 640,
              builder: (ctx, _) => const Center(child: MareWordmark(size: 20)),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                pad,
                Space.base,
                pad,
                navClearance(context),
              ),
              sliver: SliverList.list(
                children: [
                  // ── Cabeçalho do perfil
                  Center(
                    child: Pressable(
                      semanticLabel: 'Editar perfil',
                      onTap: () => editProfile(context),
                      child: Avatar(
                        path: d.avatarPath,
                        name: d.userName,
                        size: 96,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.base),
                  Text(
                    d.userName.isEmpty ? 'Seu perfil' : d.userName,
                    textAlign: TextAlign.center,
                    style: T.title.copyWith(color: c.text),
                  ),
                  const SizedBox(height: Space.xs),
                  Center(
                    child: Pressable(
                      semanticLabel: 'Abrir sincronização',
                      onTap: () => push(context, const SyncScreen()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.sm,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              syncIcon,
                              size: 15,
                              color: sync.pendingConflict != null
                                  ? c.accentWarm
                                  : c.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                syncLabel,
                                style: T.small.copyWith(
                                  color: sync.pendingConflict != null
                                      ? c.accentWarm
                                      : c.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.base),

                  // ── Botões lado a lado: Editar Perfil e Configurações
                  Row(
                    children: [
                      Expanded(
                        child: PillButton(
                          'Editar Perfil',
                          kind: BtnKind.ghost,
                          height: 46,
                          onTap: () => editProfile(context),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: PillButton(
                          'Configurações',
                          kind: BtnKind.ghost,
                          height: 46,
                          onTap: () => push(context, const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),

                  // ── Sugestão de primeira caixinha (some após criar uma)
                  if (d.boxes.isEmpty) ...[
                    const SectionHeader('Sugestão'),
                    AppCard(
                      onTap: () => pushFluid(context, const BoxForm()),
                      child: Row(
                        children: [
                          IconBadge(LucideIcons.piggyBank, c.primary, size: 42),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Comece uma caixinha',
                                  style: T.bodyStrong.copyWith(color: c.text),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Guarde um valor todo ciclo para metas ou reservas.',
                                  style: T.small.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 18,
                            color: c.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Finanças em grade bento (agrupando informações-chave)
                  const SectionHeader('Finanças'),
                  // Linha 1 (largura cheia): Salário + Virada do ciclo agrupados
                  _FinanceTile(
                    icon: LucideIcons.banknote,
                    title: 'Salário e ciclo',
                    onTap: () => editSalaryAndCycle(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: f.salary > 0
                                  ? MoneyText(
                                      f.salary,
                                      hidden: hidden,
                                      style: T.title,
                                    )
                                  : Text(
                                      'Informar salário',
                                      style: T.headline.copyWith(
                                        color: c.primary,
                                      ),
                                    ),
                            ),
                            Tag(
                              'Dia ${d.cycleStartDay}',
                              icon: LucideIcons.calendarSync,
                              bg: c.cardAlt,
                              fg: c.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ciclo atual: ${cy.start.day}/${cy.start.month} a ${lastDay.day}/${lastDay.month}',
                          style: T.small.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.md),

                  // Linha 2 (2 colunas): Contas e cartões + Assinaturas
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _FinanceTile(
                            icon: LucideIcons.landmark,
                            title: 'Contas',
                            expandChild: true,
                            onTap: () => manageCards(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  d.cards.isEmpty
                                      ? 'Nenhuma'
                                      : '${d.cards.length} ${d.cards.length == 1 ? 'conta' : 'contas'}',
                                  style: T.cardValue.copyWith(color: c.text),
                                ),
                                const SizedBox(height: 6),
                                if (d.cards.isEmpty)
                                  Text(
                                    'Toque para adicionar',
                                    style: T.small.copyWith(
                                      color: c.textSecondary,
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      for (final k in d.cards.take(5))
                                        Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.only(
                                            right: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(k.color),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      if (d.cards.length > 5)
                                        Text(
                                          '+${d.cards.length - 5}',
                                          style: T.tiny.copyWith(
                                            color: c.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: _FinanceTile(
                            icon: LucideIcons.tv,
                            title: 'Assinaturas',
                            expandChild: true,
                            onTap: () =>
                                push(context, const SubscriptionsScreen()),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                subs.isEmpty
                                    ? Text(
                                        'Nenhuma',
                                        style: T.cardValue.copyWith(
                                          color: c.text,
                                        ),
                                      )
                                    : MoneyText(
                                        subsTotal,
                                        hidden: hidden,
                                        style: T.cardValue,
                                      ),
                                const SizedBox(height: 4),
                                Text(
                                  subs.isEmpty
                                      ? 'Serviços recorrentes'
                                      : '${subs.length} ${subs.length == 1 ? 'serviço' : 'serviços'}/mês',
                                  style: T.small.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.md),

                  // Linha 3 (2 colunas): Histórico + Categorias
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _FinanceTile(
                            icon: LucideIcons.chartColumn,
                            title: 'Histórico',
                            expandChild: true,
                            onTap: () => push(context, const HistoryScreen()),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '$activeCycles ${activeCycles == 1 ? 'ciclo' : 'ciclos'}',
                                  style: T.cardValue.copyWith(color: c.text),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Livre: ${fmtMoney(f.freeBalance(cy), hidden: hidden)}',
                                  style: T.small.copyWith(
                                    color: c.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: _FinanceTile(
                            icon: LucideIcons.chartPie,
                            title: 'Categorias',
                            expandChild: true,
                            onTap: () =>
                                push(context, const CategoriesScreen()),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  topCat?.key.label ?? 'Sem gastos',
                                  style: T.cardValue.copyWith(color: c.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  topCat == null || catTotal == 0
                                      ? 'Divisão do ciclo'
                                      : '${(topCat.value / catTotal * 100).round()}% no topo',
                                  style: T.small.copyWith(
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// Card do grid bento de Finanças no Perfil: ícone + título + seta ↗ no topo e
/// a principal métrica logo abaixo.
class _FinanceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback onTap;
  final bool expandChild;
  const _FinanceTile({
    required this.icon,
    required this.title,
    required this.child,
    required this.onTap,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      onTap: onTap,
      expandChild: expandChild,
      titleWidget: Row(
        children: [
          Icon(icon, size: 17, color: c.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: T.label.copyWith(
                color: c.text,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Tela de Configurações (Aparência + Seus dados / Sincronização / Backup).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final sync = context.sync;
    final d = s.data;
    final pad = sidePadding(context, maxWidth: 640);
    final currentSeed = d.accentColor ?? accentPresets.first.$2.toARGB32();

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
                    maxWidth: 640,
                    builder: (ctx, progress) => Row(
                      children: [
                        const BackChevron(),
                        Expanded(
                          child: BarTitle('Configurações', progress: progress),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.xl),
                    sliver: SliverList.list(
                      children: [
                        LargeTitle('Configurações', style: T.pageTitle),
                        const SizedBox(height: Space.xs),
                        Text(
                          'Aparência, sincronização e backup dos seus dados',
                          style: T.label.copyWith(color: c.textSecondary),
                        ),
                        const SectionHeader('Aparência'),
                        _Group(
                          children: [
                            _Row(
                              icon: LucideIcons.sunMoon,
                              title: 'Tema',
                              value: switch (d.theme) {
                                ThemePref.auto => 'Automático',
                                ThemePref.light => 'Claro',
                                ThemePref.dark => 'Escuro',
                              },
                              onTap: () => _pickTheme(context),
                            ),
                            _Row(
                              icon: LucideIcons.palette,
                              title: 'Cor de destaque',
                              subtitle: 'A cor secundária se ajusta ao tema',
                              trailing: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: Color(currentSeed),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: c.borderStrong),
                                ),
                              ),
                              onTap: () => _pickAccent(context),
                            ),
                          ],
                        ),
                        const SectionHeader('Seus dados'),
                        _Group(
                          children: [
                            _Row(
                              icon: LucideIcons.cloud,
                              title: 'Sincronização',
                              subtitle: syncSummaryLabel(sync),
                              value: sync.isConnected
                                  ? (sync.pendingConflict != null
                                        ? 'Conflito'
                                        : 'Ativa')
                                  : 'Desconectada',
                              onTap: () => push(context, const SyncScreen()),
                            ),
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
                            _Row(
                              icon: LucideIcons.trash2,
                              title: 'Apagar dados do aparelho',
                              danger: true,
                              onTap: () => _resetAll(context),
                            ),
                          ],
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

  Future<void> _pickTheme(BuildContext context) async {
    final s = context.storeRead;
    final v = await actionSheet<ThemePref>(
      context,
      title: 'Tema',
      actions: const [
        SheetAction('Automático', ThemePref.auto, icon: LucideIcons.smartphone),
        SheetAction('Claro', ThemePref.light, icon: LucideIcons.sun),
        SheetAction('Escuro', ThemePref.dark, icon: LucideIcons.moon),
      ],
    );
    if (v != null) s.setTheme(v);
  }

  Future<void> _pickAccent(BuildContext context) {
    return showSheet<void>(
      context,
      edgeToEdge: true,
      builder: (ctx) {
        final c = ctx.c;
        final s = ctx.store;
        final seed = s.data.accentColor ?? accentPresets.first.$2.toARGB32();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            20,
            Space.gutter,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cor de destaque',
                style: T.headline.copyWith(color: c.text),
              ),
              const SizedBox(height: 4),
              Text(
                'A cor secundária se ajusta sozinha ao tema.',
                style: T.small.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: Space.base,
                runSpacing: Space.base,
                children: [
                  for (final (label, col) in accentPresets)
                    _AccentSwatch(
                      label: label,
                      primary: col,
                      complementary: complementaryOf(col),
                      selected: seed == col.toARGB32(),
                      onTap: () => s.setAccentColor(col.toARGB32()),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resetAll(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Apagar tudo?',
      message:
          'Gastos, caixinhas, cartões e perfil serão apagados deste celular. Exporte um backup antes se quiser guardar.',
      action: 'Apagar tudo',
    );
    if (!ok || !context.mounted) return;
    final ok2 = await confirm(
      context,
      title: 'Tem certeza?',
      message: 'Não dá para desfazer.',
      action: 'Sim, apagar',
    );
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
          border: Border.all(
            color: selected ? c.text : c.border,
            width: selected ? 2.5 : 1,
          ),
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
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                    ),
                  ),
                ),
              ),
              if (selected)
                const Center(
                  child: Icon(
                    LucideIcons.check,
                    size: 16,
                    color: Palette.neutral0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) => ListGroup(children: children);
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListRow(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(icon, size: 24, color: danger ? c.negative : c.text),
        ),
      ),
      title: title,
      subtitle: subtitle,
      value: value,
      trailing: trailing,
      arrow: onTap != null && trailing == null,
      onTap: onTap,
    );
  }
}

// ── Sheets ──────────────────────────────────────────────────

Future<void> editSalary(BuildContext context) =>
    editSalaryAndCycle(context, initialTab: 0);

Future<void> editCycleDay(BuildContext context) =>
    editSalaryAndCycle(context, initialTab: 1);

/// Sheet unificado de Salário + Virada do ciclo (agrupados no Perfil).
Future<void> editSalaryAndCycle(BuildContext context, {int initialTab = 0}) =>
    showIosSheet<void>(
      context,
      builder: (_) => _SalaryCycleSheet(initialTab: initialTab),
    );

class _SalaryCycleSheet extends StatefulWidget {
  final int initialTab;
  const _SalaryCycleSheet({this.initialTab = 0});
  @override
  State<_SalaryCycleSheet> createState() => _SalaryCycleSheetState();
}

class _SalaryCycleSheetState extends State<_SalaryCycleSheet> {
  late int _tab = widget.initialTab;
  late final _ctl = AmountController(context.storeRead.f.salary);
  late int _day = context.storeRead.data.cycleStartDay;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _ctl.removeListener(_refresh);
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.storeRead;
    final cy = Cycle.of(DateTime.now(), _day);
    final last = cy.end.subtract(const Duration(days: 1));
    return SheetBody(
      bottom: PillButton(
        'Salvar',
        onTap: () {
          final err = s.setSalary(_ctl.value);
          if (err != null) {
            toast(context, err, icon: LucideIcons.triangleAlert);
            return;
          }
          s.setCycleStartDay(_day);
          Navigator.pop(context);
          toast(context, 'Salário e ciclo atualizados');
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Salário e ciclo',
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
          const SizedBox(height: Space.md),
          Segmented<int>(
            value: _tab,
            options: const {0: 'Salário', 1: 'Virada do ciclo'},
            onChanged: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: Space.base),
          if (_tab == 0) ...[
            Text(
              'Valor líquido que entra por ciclo. Vale a partir deste ciclo; os anteriores mantêm o valor antigo.',
              style: T.small.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 20),
            Center(child: AmountDisplay(cents: _ctl.value, size: 46)),
            const SizedBox(height: 18),
            Keypad(controller: _ctl),
          ] else ...[
            Text(
              'Use o dia em que o salário cai. Em meses mais curtos, a virada acontece no último dia.',
              style: T.small.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: _day - 1,
                ),
                itemExtent: 46,
                onSelectedItemChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _day = i + 1);
                },
                children: [
                  for (var d = 1; d <= 31; d++)
                    Center(
                      child: Text(
                        'Dia $d',
                        style: T.headline.copyWith(
                          color: d == _day ? c.primary : c.text,
                          fontWeight:
                              d == _day ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: BlurSwitcher(
                alignment: Alignment.center,
                child: Text(
                  'Ciclo atual: ${cy.start.day}/${cy.start.month} a ${last.day}/${last.month}',
                  key: ValueKey(_day),
                  style: T.label.copyWith(color: c.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> manageCards(BuildContext context) {
  return showIosSheet<void>(
    context,
    builder: (ctx) {
      final c = ctx.c;
      final s = ctx.store;
      final cards = s.data.cards;
      return SheetBody(
        bottom: PillButton(
          'Adicionar conta ou cartão',
          icon: LucideIcons.plus,
          onTap: () => editCard(ctx),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Contas e cartões',
                    style: T.title.copyWith(color: c.text),
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
            const SizedBox(height: Space.xs),
            Text(
              'Adicione bancos ou cartões para filtrar seus gastos no extrato. Segure um item na Carteira para editar.',
              style: T.small.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.base),
            if (cards.isEmpty)
              const EmptyState(
                icon: LucideIcons.landmark,
                title: 'Nenhuma conta cadastrada',
                message: 'Adicione seu banco ou cartão para separar os gastos.',
              )
            else
              ListGroup(
                children: [
                  for (final k in cards)
                    ListRow(
                      leading: CardChip(card: k, width: 72),
                      title: k.name,
                      subtitle:
                          k.last4.isNotEmpty ? 'Final ${k.last4}' : 'Conta',
                      arrow: true,
                      onTap: () => editCard(ctx, card: k),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

Future<void> editProfile(BuildContext context) =>
    showIosSheet<void>(context, builder: (_) => const _ProfileForm());

class _ProfileForm extends StatefulWidget {
  const _ProfileForm();
  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _name = TextEditingController(
    text: context.storeRead.data.userName,
  );
  late String? _avatar = context.storeRead.data.avatarPath;
  bool _removed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
      );
      if (x == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final dest = File(
        '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await File(x.path).copy(dest.path);
      setState(() {
        _avatar = dest.path;
        _removed = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sync = context.sync;
    final googlePhoto = sync.accountPhotoUrl;
    final hasGooglePhoto = googlePhoto != null && googlePhoto.isNotEmpty;

    return SheetBody(
      bottom: PillButton(
        'Salvar',
        onTap: () {
          context.storeRead.setProfile(
            name: _name.text,
            avatarPath: _removed ? null : _avatar,
            clearAvatar: _removed,
          );
          Navigator.pop(context);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Editar perfil',
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
          const SizedBox(height: 20),
          Center(
            child: Pressable(
              onTap: () async {
                final a = await actionSheet<String>(
                  context,
                  actions: [
                    if (hasGooglePhoto)
                      const SheetAction(
                        'Usar foto da conta Google',
                        'google',
                        icon: LucideIcons.cloud,
                      ),
                    const SheetAction(
                      'Escolher da galeria',
                      'gallery',
                      icon: LucideIcons.image,
                    ),
                    const SheetAction(
                      'Tirar foto',
                      'camera',
                      icon: LucideIcons.camera,
                    ),
                    if (_avatar != null)
                      const SheetAction(
                        'Remover foto',
                        'remove',
                        destructive: true,
                        icon: LucideIcons.trash2,
                      ),
                  ],
                );
                if (a == 'google' && hasGooglePhoto) {
                  setState(() {
                    _avatar = googlePhoto;
                    _removed = false;
                  });
                }
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
                        border: Border.all(color: c.card, width: 2),
                      ),
                      child: Icon(
                        LucideIcons.camera,
                        size: 16,
                        color: c.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasGooglePhoto && _avatar != googlePhoto) ...[
            const SizedBox(height: Space.md),
            Center(
              child: ChipButton(
                'Usar foto da conta Google',
                icon: LucideIcons.cloud,
                onTap: () => setState(() {
                  _avatar = googlePhoto;
                  _removed = false;
                }),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const FieldLabel('Nome'),
          AppField(
            controller: _name,
            placeholder: 'Seu nome',
            capitalization: TextCapitalization.words,
            maxLength: 30,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
