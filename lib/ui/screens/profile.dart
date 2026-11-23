import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/color_engine.dart';
import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/drive_sync.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets/avatar_cropper.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/nav_keypad.dart';
import 'ai_import.dart';
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

                  // ── Sugestão de primeira caixinha (some após criar uma ou dispensar)
                  if (d.boxes.isEmpty && !d.dismissedBoxTip) ...[
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
                          const SizedBox(width: Space.xs),
                          RoundIconButton(
                            LucideIcons.x,
                            size: 32,
                            bg: c.cardAlt,
                            label: 'Dispensar sugestão',
                            onTap: s.dismissBoxTip,
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
                                      style: T.cardValue.copyWith(fontSize: 20),
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
                  const SizedBox(height: Space.sm),

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
                                  style: T.headline.copyWith(color: c.text),
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
                        const SizedBox(width: Space.sm),
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
                                        style: T.headline.copyWith(
                                          color: c.text,
                                        ),
                                      )
                                    : MoneyText(
                                        subsTotal,
                                        hidden: hidden,
                                        style: T.headline,
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
                  const SizedBox(height: Space.sm),

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
                                  style: T.headline.copyWith(color: c.text),
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
                        const SizedBox(width: Space.sm),
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
                                  style: T.headline.copyWith(color: c.text),
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

/// Card do grid bento de Finanças no Perfil: título + seta ↗ no topo e
/// a principal métrica logo abaixo (sem ícones para um visual mais limpo).
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
    return AppCard(
      onTap: onTap,
      expandChild: expandChild,
      title: title,
      child: child,
    );
  }
}

/// Tela de Configurações categorizada (Personalização, Sincronização e backup,
/// Aplicativo e Conta).
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
    final navTabs = effectiveNavTabs(d);

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
                        const SectionHeader('Personalização'),
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
                            _Row(
                              icon: LucideIcons.panelBottom,
                              title: 'Barra de navegação',
                              value: '${navTabs.length} abas',
                              onTap: () => _editNavBar(context),
                            ),
                          ],
                        ),
                        const SectionHeader('Sincronização e backup'),
                        _Group(
                          children: [
                            _Row(
                              icon: LucideIcons.cloud,
                              title: 'Google Drive',
                              value: sync.isConnected
                                  ? (sync.pendingConflict != null
                                        ? 'Conflito'
                                        : 'Ativa')
                                  : 'Desconectada',
                              onTap: () => push(context, const SyncScreen()),
                            ),
                            _Row(
                              icon: LucideIcons.sparkles,
                              title: 'Importar com IA',
                              onTap: () => _openAiImportMenu(context),
                            ),
                            _Row(
                              icon: LucideIcons.download,
                              title: 'Exportar backup',
                              onTap: () => exportBackupFlow(context),
                            ),
                            _Row(
                              icon: LucideIcons.upload,
                              title: 'Restaurar backup',
                              onTap: () => importBackupFlow(context),
                            ),
                          ],
                        ),
                        const SectionHeader('Aplicativo'),
                        _Group(
                          children: [
                            _Row(
                              icon: LucideIcons.info,
                              title: 'Sobre o maré',
                              value: 'v1.0',
                              onTap: () => push(context, const AboutScreen()),
                            ),
                          ],
                        ),
                        const SectionHeader('Conta'),
                        _Group(
                          children: [
                            _Row(
                              icon: LucideIcons.logOut,
                              title: 'Sair',
                              subtitle: sync.isConnected
                                  ? 'Desconectar e limpar dados'
                                  : 'Limpar dados deste aparelho',
                              danger: true,
                              onTap: () => _signOut(context),
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

  Future<void> _openAiImportMenu(BuildContext context) async {
    final choice = await actionSheet<AiImportMode>(
      context,
      title: 'Importar com agente de IA',
      message:
          'Copie as instruções prontas para o ChatGPT, Claude ou Gemini e cole o JSON gerado de volta no app.',
      actions: const [
        SheetAction(
          'Importar gastos em lote',
          AiImportMode.expenses,
          icon: LucideIcons.receipt,
        ),
        SheetAction(
          'Importar dados completos',
          AiImportMode.full,
          icon: LucideIcons.database,
        ),
      ],
    );
    if (choice == null || !context.mounted) return;
    push(context, AiImportScreen(initialMode: choice));
  }

  Future<void> _editNavBar(BuildContext context) {
    final s = context.storeRead;
    var pinned = List<String>.from(effectiveNavTabs(s.data));

    return showIosSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = ctx.c;
          final wellBg = c.isDark ? c.bg : c.surfaceLow;
          final ordered = [
            for (final id in pinned)
              navDestinations.firstWhere((n) => n.id == id),
            for (final dest in navDestinations)
              if (!pinned.contains(dest.id)) dest,
          ];
          void commit() => s.setNavTabs(pinned);

          return SheetBody(
            bottom: PillButton('Concluir', onTap: () => Navigator.pop(ctx)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Barra de navegação',
                        style: T.title.copyWith(color: c.text),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                      onPressed: () {
                        s.resetNavTabs();
                        set(
                          () => pinned = List<String>.from(
                            effectiveNavTabs(s.data),
                          ),
                        );
                        toast(ctx, 'Barra restaurada ao padrão');
                      },
                      child: Text(
                        'Restaurar',
                        style: T.labelStrong.copyWith(color: c.primary),
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
                  'Escolha de 2 a 5 telas fixadas (${pinned.length}/5) e ajuste a ordem com as setas.',
                  style: T.small.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.base),
                for (var i = 0; i < ordered.length; i++)
                  () {
                    final dest = ordered[i];
                    final pinIdx = pinned.indexOf(dest.id);
                    final isPinned = pinIdx >= 0;
                    final canToggle = dest.locked
                        ? false
                        : (isPinned ? pinned.length > 2 : pinned.length < 5);

                    return Container(
                      margin: const EdgeInsets.only(bottom: Space.sm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.md,
                        vertical: 10,
                      ),
                      decoration: ShapeDecoration(
                        color: wellBg,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            dest.icon,
                            size: 20,
                            color: isPinned ? c.primary : c.textSecondary,
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dest.label,
                                  style: T.bodyMedium.copyWith(
                                    color: isPinned ? c.text : c.textSecondary,
                                  ),
                                ),
                                Text(
                                  dest.subtitle,
                                  style: T.small.copyWith(
                                    color: c.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isPinned) ...[
                            Pressable(
                              semanticLabel: 'Mover para cima',
                              onTap: pinIdx > 0
                                  ? () {
                                      set(() {
                                        final item = pinned.removeAt(pinIdx);
                                        pinned.insert(pinIdx - 1, item);
                                      });
                                      commit();
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  LucideIcons.chevronUp,
                                  size: 18,
                                  color: pinIdx > 0
                                      ? c.textSecondary
                                      : c.textTertiary,
                                ),
                              ),
                            ),
                            Pressable(
                              semanticLabel: 'Mover para baixo',
                              onTap: pinIdx < pinned.length - 1
                                  ? () {
                                      set(() {
                                        final item = pinned.removeAt(pinIdx);
                                        pinned.insert(pinIdx + 1, item);
                                      });
                                      commit();
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  LucideIcons.chevronDown,
                                  size: 18,
                                  color: pinIdx < pinned.length - 1
                                      ? c.textSecondary
                                      : c.textTertiary,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: Space.xs),
                          if (dest.locked)
                            Tag('Fixo', bg: c.cardAlt, fg: c.textSecondary)
                          else
                            SpringSwitch(
                              value: isPinned,
                              label: dest.label,
                              onChanged: (on) {
                                if (!canToggle) {
                                  toast(
                                    ctx,
                                    on
                                        ? 'Máximo de 5 abas na barra'
                                        : 'Mantenha ao menos 2 abas fixadas',
                                    icon: LucideIcons.info,
                                  );
                                  return;
                                }
                                set(() {
                                  if (on) {
                                    // Insere antes do Perfil se ele for o último
                                    final perfilIdx = pinned.indexOf('perfil');
                                    if (perfilIdx == pinned.length - 1 &&
                                        perfilIdx > 0) {
                                      pinned.insert(perfilIdx, dest.id);
                                    } else {
                                      pinned.add(dest.id);
                                    }
                                  } else {
                                    pinned.remove(dest.id);
                                  }
                                });
                                commit();
                              },
                            ),
                        ],
                      ),
                    );
                  }(),
              ],
            ),
          );
        },
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
            4,
            Space.gutter,
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cor de destaque',
                      style: T.title.copyWith(
                        color: c.text,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  RoundIconButton(
                    LucideIcons.x,
                    size: 36,
                    bg: c.isDark ? c.cardAlt : c.surfaceLow,
                    label: 'Fechar',
                    onTap: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'A cor secundária se ajusta sozinha ao tema.',
                style: T.small.copyWith(
                  color: c.textSecondary,
                  decoration: TextDecoration.none,
                ),
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

  Future<void> _signOut(BuildContext context) async {
    final sync = context.syncRead;
    final String msg;
    if (!sync.isConnected) {
      msg =
          'Seus dados não estão sincronizados com o Google Drive. Ao sair, tudo que está salvo neste aparelho será perdido.';
    } else if (sync.hasUnsyncedChanges) {
      msg =
          'Há alterações ainda não sincronizadas com o Google Drive. Ao sair, esses dados locais serão perdidos e sua conta será desconectada deste aparelho.';
    } else {
      msg =
          'Sua conta do Google será desconectada e os dados locais serão removidos deste aparelho. O que já foi sincronizado continua salvo no Google Drive.';
    }
    final ok = await confirm(
      context,
      title: 'Sair do maré?',
      message: msg,
      action: 'Sair',
    );
    if (!ok || !context.mounted) return;
    await sync.disconnect();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
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
                Center(
                  child: Icon(
                    LucideIcons.check,
                    size: 16,
                    color: onColor(primary),
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

/// Bottom sheet compacto e padronizado de Salário + Virada do ciclo.
Future<void> editSalaryAndCycle(BuildContext context, {int initialTab = 0}) =>
    showSheet<void>(
      context,
      edgeToEdge: true,
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
  late final _dayPicker = FixedExtentScrollController(initialItem: _day - 1);

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
    _dayPicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.storeRead;
    final cy = Cycle.of(DateTime.now(), _day);
    final last = cy.end.subtract(const Duration(days: 1));
    final wellBg = c.isDark ? c.bg : c.surfaceLow;
    final keyBg = c.isDark ? c.cardAlt : c.surfaceLow;

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
                  'Salário e ciclo',
                  style: T.title.copyWith(
                    color: c.text,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              RoundIconButton(
                LucideIcons.x,
                size: 36,
                bg: keyBg,
                label: 'Fechar',
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Segmented<int>(
            value: _tab,
            trackColor: wellBg,
            options: const {0: 'Salário', 1: 'Virada do ciclo'},
            onChanged: (v) => setState(() => _tab = v),
          ),
          const SizedBox(height: Space.base),
          if (_tab == 0) ...[
            Text(
              'Valor líquido por ciclo. Vale a partir deste ciclo; os anteriores mantêm o valor antigo.',
              style: T.small.copyWith(
                color: c.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: Space.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.base,
                vertical: Space.base,
              ),
              decoration: ShapeDecoration(
                color: wellBg,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  AmountDisplay(cents: _ctl.value, size: 42),
                  const SizedBox(height: Space.md),
                  QuickAddChips(
                    controller: _ctl,
                    amounts: const [100, 250, 500, 1000],
                    chipBg: keyBg,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            Keypad(
              controller: _ctl,
              keyColor: keyBg,
              keyHeight: 54,
            ),
          ] else ...[
            Text(
              'Use o dia em que o salário cai. Em meses mais curtos, a virada acontece no último dia.',
              style: T.small.copyWith(
                color: c.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: Space.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.base,
                vertical: Space.md,
              ),
              decoration: ShapeDecoration(
                color: wellBg,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.calendarSync,
                    size: 18,
                    color: c.primary,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: BlurSwitcher(
                      child: Text(
                        'Ciclo atual: ${cy.start.day}/${cy.start.month} a ${last.day}/${last.month}',
                        key: ValueKey(_day),
                        style: T.bodyMedium.copyWith(
                          color: c.text,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  Tag(
                    'Dia $_day',
                    bg: keyBg,
                    fg: c.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            Container(
              height: 196,
              decoration: ShapeDecoration(
                color: wellBg,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: CupertinoPicker(
                scrollController: _dayPicker,
                itemExtent: 44,
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
          ],
          const SizedBox(height: Space.base),
          PillButton(
            'Salvar',
            onTap: () {
              // Atualiza o dia de virada ANTES do salário para gravar na chave correta.
              s.setCycleStartDay(_day);
              final err = s.setSalary(_ctl.value);
              if (err != null) {
                toast(context, err, icon: LucideIcons.triangleAlert);
                return;
              }
              Navigator.pop(context);
              toast(context, 'Salário e ciclo atualizados');
            },
          ),
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
              EmptyState(
                bg: c.isDark ? c.bg : c.surfaceLow,
                icon: LucideIcons.landmark,
                title: 'Nenhuma conta cadastrada',
                message: 'Adicione seu banco ou cartão para separar os gastos.',
              )
            else
              ListGroup(
                bg: c.isDark ? c.bg : c.surfaceLow,
                children: [
                  for (final k in cards)
                    ListRow(
                      leading: CardChip(card: k, width: 72),
                      title: k.name,
                      subtitle: k.isCard
                          ? (k.last4.isNotEmpty
                                ? 'Cartão •••${k.last4}'
                                : 'Cartão')
                          : 'Conta',
                      arrow: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        push(context, CardDetailScreen(cardId: k.id));
                      },
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
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (x == null || !mounted) return;
      final cropped = await cropAvatarPhoto(context, File(x.path));
      if (cropped == null || !mounted) return;
      setState(() {
        _avatar = cropped;
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
                if (!mounted) return;
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
                bg: c.isDark ? c.cardAlt : c.surfaceLow,
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
            bg: c.isDark ? c.bg : c.surfaceLow,
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

/// Tela "Sobre o maré" com informações do aplicativo, desenvolvedor e créditos.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _linkedinUrl = 'https://www.linkedin.com/in/tonyrodiv/';
  static const _linksChannel = MethodChannel('com.mare.mare/links');

  Future<void> _openLinkedIn(BuildContext context) async {
    try {
      final opened = await _linksChannel.invokeMethod<bool>(
        'openUrl',
        {'url': _linkedinUrl},
      );
      if (opened == true) return;
    } catch (_) {}
    await Clipboard.setData(const ClipboardData(text: _linkedinUrl));
    if (context.mounted) {
      toast(context, 'Link do LinkedIn copiado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pad = sidePadding(context, maxWidth: 640);

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
                          child: BarTitle('Sobre o maré', progress: progress),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, Space.base, pad, Space.xl),
                    sliver: SliverList.list(
                      children: [
                        Center(
                          child: Column(
                            children: [
                              const MareWordmark(size: 38),
                              const SizedBox(height: Space.sm),
                              Tag(
                                'Versão 1.0.0',
                                bg: c.card,
                                fg: c.textSecondary,
                              ),
                              const SizedBox(height: Space.md),
                              Text(
                                'Suas finanças no ritmo do seu ciclo.',
                                textAlign: TextAlign.center,
                                style: T.body.copyWith(color: c.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.lg),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sobre o aplicativo',
                                style: T.bodyStrong.copyWith(color: c.text),
                              ),
                              const SizedBox(height: Space.sm),
                              Text(
                                'O maré foi pensado para organizar seus gastos a partir do dia em que o seu salário cai — acompanhando saldo livre, metas em caixinhas, assinaturas e contas de um jeito simples, rápido e privado.',
                                style: T.label.copyWith(color: c.textSecondary),
                              ),
                              const SizedBox(height: Space.sm),
                              Text(
                                'Todos os seus dados ficam salvos no seu aparelho, com opção de sincronização privada na sua própria conta do Google Drive.',
                                style: T.label.copyWith(color: c.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        ListGroup(
                          title: 'Desenvolvimento',
                          children: [
                            ListRow(
                              leading: IconBadge(
                                LucideIcons.codeXml,
                                c.primary,
                                size: 40,
                              ),
                              title: 'Antony Rodrigues',
                              subtitle: 'Desenvolvedor',
                            ),
                            ListRow(
                              leading: IconBadge(
                                LucideIcons.externalLink,
                                const Color(0xFF0A66C2),
                                size: 40,
                              ),
                              title: 'LinkedIn',
                              subtitle: 'linkedin.com/in/tonyrodiv',
                              arrow: true,
                              onTap: () => _openLinkedIn(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.lg),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.sparkles,
                                size: 14,
                                color: c.textTertiary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Criado com auxílio do Claude e Antigravity',
                                  textAlign: TextAlign.center,
                                  style: T.small.copyWith(
                                    color: c.textTertiary,
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
            ),
          ],
        ),
      ),
    );
  }
}
