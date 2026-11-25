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
import '../../data/native_bridge.dart';
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
    final maxW = isWide(context) ? 820.0 : 640.0;
    final pad = sidePadding(context, maxWidth: maxW);
    final cy = f.current;
    final lastDay = cy.end.subtract(const Duration(days: 1));
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
              maxWidth: maxW,
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

                  // ── Finanças e estatísticas pessoais (estilo compacto, sem título de seção)
                  const SizedBox(height: Space.base),
                  Builder(
                    builder: (_) {
                      final totalSpent = f.expensesTotal(cy);
                      final fixedTotal = f.fixedTotal(cy);
                      final varTotal = f.variableTotal(cy);
                      final salary = f.salary;
                      final fixedPct = salary > 0
                          ? ((fixedTotal / salary) * 100).round().clamp(0, 999)
                          : (totalSpent > 0
                                ? ((fixedTotal / totalSpent) * 100).round()
                                : 0);
                      final activeCyclesList = [
                        for (final item in f.lastCycles(6))
                          if (f.expensesTotal(item) > 0) f.expensesTotal(item),
                      ];
                      final avgCycle = activeCyclesList.isEmpty
                          ? 0
                          : (activeCyclesList.fold<int>(0, (a, b) => a + b) /
                                    activeCyclesList.length)
                                .round();

                      return Column(
                        children: [
                          // Card 1: Salário e virada do ciclo (clicável)
                          _FinanceTile(
                            icon: LucideIcons.banknote,
                            title: 'Salário e ciclo',
                            onTap: () => editSalaryAndCycle(context),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      salary > 0
                                          ? MoneyText(
                                              salary,
                                              hidden: hidden,
                                              style: T.cardValue,
                                            )
                                          : Text(
                                              'Informar salário',
                                              style: T.headline.copyWith(
                                                color: c.primary,
                                              ),
                                            ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${cy.start.day}/${cy.start.month} a ${lastDay.day}/${lastDay.month}',
                                        style: T.small.copyWith(
                                          color: c.textSecondary,
                                        ),
                                      ),
                                    ],
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
                          ),
                          const SizedBox(height: Space.sm),

                          // Linha 2: Estatísticas pessoais (Fixos vs. Dia a dia + Média mensal)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _FinanceTile(
                                    icon: LucideIcons.repeat,
                                    title: 'Custos fixos',
                                    expandChild: true,
                                    onTap: () => push(
                                      context,
                                      const SubscriptionsScreen(),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        MoneyText(
                                          fixedTotal,
                                          hidden: hidden,
                                          style: T.headline,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          salary > 0
                                              ? '$fixedPct% do salário'
                                              : 'Dia a dia: ${fmtMoney(varTotal, hidden: hidden)}',
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
                                    icon: LucideIcons.chartColumn,
                                    title: 'Média mensal',
                                    expandChild: true,
                                    onTap: () =>
                                        push(context, const HistoryScreen()),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        MoneyText(
                                          avgCycle,
                                          hidden: hidden,
                                          style: T.headline,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$activeCycles ${activeCycles == 1 ? 'ciclo registrado' : 'ciclos registrados'}',
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
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.sm),

                          // Linha 3: Contas e cartões + Maior gasto
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _FinanceTile(
                                    icon: LucideIcons.creditCard,
                                    title: 'Contas',
                                    expandChild: true,
                                    onTap: () => manageCards(context),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          d.cards.isEmpty
                                              ? 'Nenhuma'
                                              : '${d.cards.length} ${d.cards.length == 1 ? 'conta' : 'contas'}',
                                          style: T.headline.copyWith(
                                            color: c.text,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        if (d.cards.isEmpty)
                                          Text(
                                            'Toque para adicionar',
                                            style: T.small.copyWith(
                                              color: c.textSecondary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Space.sm),
                                Expanded(
                                  child: _FinanceTile(
                                    icon: LucideIcons.chartPie,
                                    title: 'Maior gasto',
                                    expandChild: true,
                                    onTap: () =>
                                        push(context, const CategoriesScreen()),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          topCat?.key.label ?? 'Sem gastos',
                                          style: T.headline.copyWith(
                                            color: c.text,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          topCat == null || catTotal == 0
                                              ? 'Neste ciclo'
                                              : '${(topCat.value / catTotal * 100).round()}% · ${fmtMoney(topCat.value, hidden: hidden)}',
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
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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

/// Tela de Configurações categorizada (Aparência, Navegação e ciclo,
/// Nuvem e dados, Aplicativo e Conta).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final sync = context.sync;
    final d = s.data;
    final twoCols = MediaQuery.sizeOf(context).width >= 840;
    final maxW = twoCols ? 1020.0 : (isWide(context) ? 820.0 : 640.0);
    final pad = sidePadding(context, maxWidth: maxW);
    final currentSeed = d.accentColor ?? accentThemes.first.primary.toARGB32();
    final themeSpec = accentThemeFor(Color(currentSeed));
    final navTabs = effectiveNavTabs(d);

    final appearanceSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Aparência e navegação'),
        _Group(
          children: [
            _Row(
              icon: LucideIcons.sunMoon,
              title: 'Modo de cor',
              value: switch (d.theme) {
                ThemePref.auto => 'Automático',
                ThemePref.light => 'Claro',
                ThemePref.dark => 'Escuro',
              },
              onTap: () => _pickTheme(context),
            ),
            _Row(
              icon: LucideIcons.palette,
              title: 'Tema e destaque',
              value: themeSpec.name,
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
      ],
    );

    final financeSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Finanças'),
        _Group(
          children: [
            _Row(
              icon: LucideIcons.calendarSync,
              title: 'Salário e virada do ciclo',
              value: 'Dia ${d.cycleStartDay}',
              onTap: () => editSalaryAndCycle(context),
            ),
            _Row(
              icon: LucideIcons.landmark,
              title: 'Contas e cartões',
              value: d.cards.isEmpty ? 'Nenhuma' : '${d.cards.length}',
              onTap: () => manageCards(context),
            ),
          ],
        ),
        if (isAndroidNative) ...[
          const SectionHeader('Automações e tela inicial'),
          _Group(
            children: [
              _Row(
                icon: LucideIcons.bellRing,
                title: 'Detectar gastos de bancos',
                onTap: () => _openBankNotificationsSheet(context),
              ),
              _Row(
                icon: LucideIcons.layoutGrid,
                title: 'Widgets na tela inicial',
                onTap: () => _openHomeWidgetsSheet(context),
              ),
            ],
          ),
        ],
      ],
    );

    final cloudSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Nuvem e dados'),
        _Group(
          children: [
            _Row(
              icon: LucideIcons.cloud,
              title: 'Google Drive',
              value: sync.isConnected
                  ? (sync.pendingConflict != null ? 'Conflito' : 'Ativa')
                  : 'Desconectada',
              onTap: () => push(context, const SyncScreen()),
            ),
            _Row(
              icon: LucideIcons.sparkles,
              title: 'Importar com IA',
              onTap: () => push(context, const AiImportScreen()),
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
        const SectionHeader('Recursos experimentais'),
        _Group(
          children: [
            _Row(
              icon: LucideIcons.users,
              title: 'Dividir gastos',
              trailing: CupertinoSwitch(
                value: d.expSplitExpenses,
                activeTrackColor: c.primary,
                onChanged: (v) => s.setExperimental(splitExpenses: v),
              ),
              onTap: () => s.setExperimental(splitExpenses: !d.expSplitExpenses),
            ),
            _Row(
              icon: LucideIcons.image,
              title: 'Cabeçalho personalizado',
              trailing: CupertinoSwitch(
                value: d.expProfileHeader,
                activeTrackColor: c.primary,
                onChanged: (v) => s.setExperimental(profileHeader: v),
              ),
              onTap: () => s.setExperimental(profileHeader: !d.expProfileHeader),
            ),
          ],
        ),
        const SectionHeader('Aplicativo'),
        _Group(
          children: [
            _Row(
              icon: LucideIcons.info,
              title: 'Sobre o maré',
              value: 'v1.6',
              onTap: () => push(context, const AboutScreen()),
            ),
            _Row(
              icon: LucideIcons.logOut,
              title: 'Sair e limpar aparelho',
              danger: true,
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ],
    );

    return SheetScaler(
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: Stack(
          children: [
            const GlowBackground(height: 440, useHeader: false),
            CollapsingTitleScope(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  PinnedCupertinoBar(
                    height: 60,
                    maxWidth: maxW,
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
                        if (twoCols)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    appearanceSection,
                                    financeSection,
                                  ],
                                ),
                              ),
                              const SizedBox(width: Space.lg),
                              Expanded(child: cloudSection),
                            ],
                          )
                        else ...[
                          appearanceSection,
                          financeSection,
                          cloudSection,
                        ],
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

  Future<void> _openBankNotificationsSheet(BuildContext context) async {
    var enabled = await BankNotifications.isEnabled();
    var hasAccess = await BankNotifications.hasAccess();
    var hasPost = await BankNotifications.hasPostPermission();
    if (!context.mounted) return;

    await showSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = ctx.c;
          final wellBg = c.isDark ? c.cardAlt : c.surfaceLow;
          Future<void> refresh() async {
            enabled = await BankNotifications.isEnabled();
            hasAccess = await BankNotifications.hasAccess();
            hasPost = await BankNotifications.hasPostPermission();
            if (ctx.mounted) set(() {});
          }

          final expHeader = context.storeRead.data.expProfileHeader;
    return SheetBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detectar gastos de bancos',
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
                  'Lê apenas notificações de compras e Pix enviados dos bancos suportados (100% offline no aparelho) para sugerir o lançamento com 1 toque.',
                  style: T.small.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.base),
                ListGroup(
                  bg: wellBg,
                  children: [
                    ListRow(
                      title: 'Sugestão rápida ativa',
                      subtitle: enabled
                          ? 'Dispara notificação com botão Salvar'
                          : 'Desativado',
                      trailing: SpringSwitch(
                        value: enabled,
                        label: 'Sugestão rápida ativa',
                        onChanged: (v) async {
                          await BankNotifications.setEnabled(v);
                          if (v && !hasPost) {
                            await BankNotifications.requestPostPermission();
                          }
                          await refresh();
                        },
                      ),
                    ),
                    ListRow(
                      title: 'Acesso às notificações',
                      subtitle: hasAccess
                          ? 'Permissão concedida no Android'
                          : 'Necessário para ler alertas dos bancos',
                      trailing: Tag(
                        hasAccess ? 'Ativo' : 'Pendente',
                        bg: hasAccess ? c.positiveSoft : c.card,
                        fg: hasAccess ? c.positive : c.textSecondary,
                      ),
                      onTap: () async {
                        await BankNotifications.openAccessSettings();
                        await Future.delayed(const Duration(milliseconds: 500));
                        await refresh();
                      },
                    ),
                  ],
                ),
                if (!hasAccess) ...[
                  const SizedBox(height: Space.md),
                  PillButton(
                    'Permitir acesso às notificações',
                    icon: LucideIcons.shieldCheck,
                    onTap: () async {
                      await BankNotifications.openAccessSettings();
                      await Future.delayed(const Duration(milliseconds: 500));
                      await refresh();
                    },
                  ),
                  const SizedBox(height: Space.sm),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: BankNotifications.openAppInfoSettings,
                    child: Text(
                      'No Android 13+ (APK), toque em ⋮ → Permitir configurações restritas em Info do app',
                      style: T.small.copyWith(color: c.primary),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openHomeWidgetsSheet(BuildContext context) async {
    final canPin = await NativeWidgets.canPin();
    await NativeWidgets.syncFromStore(context.storeRead);
    if (!context.mounted) return;

    await showSheet<void>(
      context,
      builder: (ctx) {
        final c = ctx.c;
        final wellBg = c.isDark ? c.cardAlt : c.surfaceLow;
        final expHeader = context.storeRead.data.expProfileHeader;
    return SheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Widgets na tela inicial',
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
                'Acompanhe o saldo livre e adicione gastos direto da tela inicial do celular.',
                style: T.small.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: Space.base),
              ListGroup(
                bg: wellBg,
                children: [
                  for (final (kind, icon, color, title, sub) in [
                    (
                      'quick_add',
                      LucideIcons.plus,
                      c.primary,
                      'Adicionar gasto rápido',
                      'Atalho direto para registrar um novo gasto',
                    ),
                    (
                      'balance',
                      LucideIcons.wallet,
                      c.primary,
                      'Saldo livre',
                      'Saldo do ciclo + atalho "+"',
                    ),
                    (
                      'summary',
                      LucideIcons.layoutGrid,
                      c.accentWarm,
                      'Resumo do ciclo',
                      'Saldo livre, gastos, caixinhas e "+ Gasto"',
                    ),
                    (
                      'expenses',
                      LucideIcons.receipt,
                      c.negative,
                      'Seus Gastos',
                      'Total gasto no ciclo atual',
                    ),
                    (
                      'boxes',
                      LucideIcons.piggyBank,
                      c.positive,
                      'Caixinhas',
                      'Total guardado nas caixinhas ativas',
                    ),
                    (
                      'subs',
                      LucideIcons.tv,
                      c.primary,
                      'Assinaturas',
                      'Custo mensal dos serviços recorrentes',
                    ),
                    (
                      'categories',
                      LucideIcons.chartPie,
                      c.accentWarm,
                      'Por categoria',
                      'Principais categorias de gastos do ciclo',
                    ),
                  ])
                    ListRow(
                      leading: IconBadge(icon, color, size: 38),
                      title: title,
                      subtitle: sub,
                      arrow: canPin,
                      onTap: canPin
                          ? () async {
                              final ok = await NativeWidgets.pinWidget(kind);
                              if (ctx.mounted && ok) {
                                Navigator.pop(ctx);
                              }
                            }
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                canPin
                    ? 'Toque em um widget para fixar ou segure a tela inicial do celular → Widgets → maré.'
                    : 'Segure a tela inicial do celular → Widgets → maré para adicionar.',
                style: T.small.copyWith(color: c.textTertiary),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editNavBar(BuildContext context) {
    final s = context.storeRead;
    var pinned = List<String>.from(effectiveNavTabs(s.data));
    var previewIndex = 0;

    return showSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = ctx.c;
          final wellBg = c.isDark ? c.cardAlt : c.surfaceLow;
          void commit() => s.setNavTabs(pinned);

          final expHeader = context.storeRead.data.expProfileHeader;
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
                        set(() {
                          pinned = List<String>.from(effectiveNavTabs(s.data));
                          previewIndex = 0;
                        });
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
                  'Toque nos blocos abaixo para ativar ou remover da barra (${pinned.length}/4).',
                  style: T.small.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: Space.base),

                // ── Pré-visualização ao vivo da barra de navegação
                Container(
                  height: 62,
                  padding: const EdgeInsets.all(5),
                  decoration: ShapeDecoration(
                    color: wellBg,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < pinned.length; i++)
                        () {
                          final dest = navDestinations.firstWhere(
                            (n) => n.id == pinned[i],
                            orElse: () => navDestinations.first,
                          );
                          final active =
                              previewIndex.clamp(0, pinned.length - 1) == i;
                          return Expanded(
                            child: Pressable(
                              scale: 0.96,
                              onTap: () => set(() => previewIndex = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: ShapeDecoration(
                                  color: active
                                      ? (c.isDark ? c.surfaceHigh : c.card)
                                      : const Color(0x00000000),
                                  shape: const StadiumBorder(),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (dest.id == 'perfil')
                                      Avatar(
                                        path: s.data.avatarPath,
                                        name: s.data.userName,
                                        size: 20,
                                      )
                                    else
                                      Icon(
                                        dest.icon,
                                        size: 18,
                                        color: active
                                            ? c.text
                                            : c.textSecondary,
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dest.label,
                                      style: T.tiny.copyWith(
                                        color: active
                                            ? c.text
                                            : c.textSecondary,
                                        fontWeight: active
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }(),
                    ],
                  ),
                ),
                const SizedBox(height: Space.base),

                // ── Grade 2 colunas para escolher as abas
                LayoutBuilder(
                  builder: (_, box) {
                    const gap = 10.0;
                    final tileW = (box.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final dest in navDestinations)
                          () {
                            final pinIdx = pinned.indexOf(dest.id);
                            final isPinned = pinIdx >= 0;
                            final (selBg, selFg) = softActionTone(
                              c.palette.primary[500],
                              isDark: c.isDark,
                            );
                            return Pressable(
                              scale: 0.97,
                              onTap: () {
                                if (dest.locked) {
                                  toast(
                                    ctx,
                                    'Seu Perfil fica sempre fixo na barra',
                                    icon: LucideIcons.lock,
                                  );
                                  return;
                                }
                                if (isPinned && pinned.length <= 2) {
                                  toast(
                                    ctx,
                                    'Mantenha ao menos 2 abas fixadas',
                                    icon: LucideIcons.info,
                                  );
                                  return;
                                }
                                if (!isPinned && pinned.length >= 4) {
                                  toast(
                                    ctx,
                                    'Máximo de 4 abas na barra',
                                    icon: LucideIcons.info,
                                  );
                                  return;
                                }
                                HapticFeedback.selectionClick();
                                set(() {
                                  if (isPinned) {
                                    pinned.remove(dest.id);
                                  } else {
                                    final perfilIdx = pinned.indexOf('perfil');
                                    if (perfilIdx == pinned.length - 1 &&
                                        perfilIdx > 0) {
                                      pinned.insert(perfilIdx, dest.id);
                                    } else {
                                      pinned.add(dest.id);
                                    }
                                  }
                                });
                                commit();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: tileW,
                                height: 74,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.md,
                                  vertical: 10,
                                ),
                                decoration: ShapeDecoration(
                                  color: isPinned ? selBg : wellBg,
                                  shape: RoundedSuperellipseBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          dest.icon,
                                          size: 20,
                                          color: isPinned
                                              ? selFg
                                              : c.textSecondary,
                                        ),
                                        const Spacer(),
                                        if (dest.locked)
                                          Icon(
                                            LucideIcons.lock,
                                            size: 14,
                                            color: isPinned
                                                ? selFg.withValues(alpha: 0.8)
                                                : c.textTertiary,
                                          )
                                        else if (isPinned)
                                          Container(
                                            width: 20,
                                            height: 20,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: selFg.withValues(
                                                alpha: 0.18,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${pinIdx + 1}',
                                              style: T.tiny.copyWith(
                                                color: selFg,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      dest.label,
                                      style:
                                          (isPinned
                                                  ? T.bodyStrong
                                                  : T.bodyMedium)
                                              .copyWith(
                                                color: isPinned
                                                    ? selFg
                                                    : c.textSecondary,
                                              ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }(),
                      ],
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

  Future<void> _pickTheme(BuildContext context) {
    final s = context.storeRead;
    return showSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = ctx.c;
          final cur = s.data.theme;
          final wellBg = c.isDark ? c.cardAlt : c.surfaceLow;
          final items = const [
            (
              ThemePref.auto,
              'Automático',
              'Segue o modo claro ou escuro do sistema',
              LucideIcons.smartphone,
            ),
            (
              ThemePref.light,
              'Claro',
              'Fundo claro durante todo o dia',
              LucideIcons.sun,
            ),
            (
              ThemePref.dark,
              'Escuro',
              'Fundo escuro para maior conforto visual',
              LucideIcons.moon,
            ),
          ];
          final expHeader = context.storeRead.data.expProfileHeader;
    return SheetBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Modo de cor',
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
                const SizedBox(height: Space.md),
                ListGroup(
                  bg: wellBg,
                  children: [
                    for (final (pref, label, sub, icon) in items)
                      ListRow(
                        leading: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: Icon(
                              icon,
                              size: 20,
                              color: cur == pref ? c.primary : c.textSecondary,
                            ),
                          ),
                        ),
                        title: label,
                        subtitle: sub,
                        trailing: cur == pref
                            ? Icon(
                                LucideIcons.check,
                                size: 20,
                                color: c.primary,
                              )
                            : null,
                        onTap: () {
                          s.setTheme(pref);
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAccent(BuildContext context) {
    return showSheet<void>(
      context,
      builder: (ctx) {
        final c = ctx.c;
        final s = ctx.store;
        final seed =
            s.data.accentColor ?? accentThemes.first.primary.toARGB32();
        final wellBg = c.isDark ? c.cardAlt : c.surfaceLow;
        final expHeader = context.storeRead.data.expProfileHeader;
    return SheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tema e destaque',
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
              const SizedBox(height: 4),
              Text(
                'Cada opção aplica sua paleta e seu gradiente atmosférico ao app.',
                style: T.small.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: Space.base),
              LayoutBuilder(
                builder: (_, box) {
                  const gap = 10.0;
                  final tileW = (box.maxWidth - gap * 2) / 3;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final themeSpec in accentThemes)
                        () {
                          final col = themeSpec.primary;
                          final selected = seed == col.toARGB32();
                          final (selBg, selFg) = softActionTone(
                            col,
                            isDark: c.isDark,
                          );
                          return Pressable(
                            scale: 0.96,
                            onTap: () => s.setAccentColor(col.toARGB32()),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: tileW,
                              height: 78,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.xs,
                                vertical: Space.xs,
                              ),
                              decoration: ShapeDecoration(
                                color: selected ? selBg : wellBg,
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
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
                                              size: 15,
                                              color: onColor(col),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    themeSpec.name,
                                    style:
                                        (selected ? T.smallStrong : T.small)
                                            .copyWith(
                                              color: selected ? selFg : c.text,
                                            ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }(),
                    ],
                  );
                },
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

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) => ListGroup(children: children);
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  const _Row({
    required this.icon,
    required this.title,
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
      value: value,
      trailing: trailing,
      arrow: trailing == null && onTap != null,
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
    final wellBg = c.isDark ? c.cardAlt : c.surfaceLow;
    final keyBg = c.isDark ? c.surfaceHigh : c.card;

    final expHeader = context.storeRead.data.expProfileHeader;
    return SheetBody(
      bottom: PillButton(
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
        ],
      ),
    );
  }
}

Future<void> manageCards(BuildContext context) {
  return showSheet<void>(
    context,
    builder: (ctx) {
      final c = ctx.c;
      final s = ctx.store;
      final cards = s.data.cards;
      final expHeader = context.storeRead.data.expProfileHeader;
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
                bg: c.isDark ? c.cardAlt : c.surfaceLow,
                icon: LucideIcons.landmark,
                title: 'Nenhuma conta cadastrada',
                message: 'Adicione seu banco ou cartão para separar os gastos.',
              )
            else
              ListGroup(
                bg: c.isDark ? c.cardAlt : c.surfaceLow,
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
    showSheet<void>(context, builder: (_) => const _ProfileForm());

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
  late String? _header = context.storeRead.data.headerPath;
  bool _removed = false;
  bool _headerRemoved = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickHeader() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );
      if (x == null || !mounted) return;
      setState(() {
        _header = x.path;
        _headerRemoved = false;
      });
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Não foi possível usar essa imagem',
          icon: LucideIcons.triangleAlert,
        );
      }
    }
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

    final expHeader = context.storeRead.data.expProfileHeader;
    return SheetBody(
      bottom: PillButton(
        'Salvar',
        onTap: () {
          context.storeRead.setProfile(
            name: _name.text,
            avatarPath: _removed ? null : _avatar,
            clearAvatar: _removed,
            headerPath: _headerRemoved ? null : _header,
            clearHeader: _headerRemoved,
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
          const SizedBox(height: 16),
          if (expHeader)
          // Banner de capa por trás da foto de perfil (avatar metade dentro, metade fora)
          SizedBox(
            height: 172,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Pressable(
                  scale: 0.98,
                  semanticLabel: 'Alterar imagem de cabeçalho',
                  onTap: () async {
                    if (_header == null) {
                      await _pickHeader();
                      return;
                    }
                    final a = await actionSheet<String>(
                      context,
                      actions: const [
                        SheetAction(
                          'Trocar imagem de cabeçalho',
                          'gallery',
                          icon: LucideIcons.image,
                        ),
                        SheetAction(
                          'Remover cabeçalho',
                          'remove',
                          destructive: true,
                          icon: LucideIcons.trash2,
                        ),
                      ],
                    );
                    if (!mounted) return;
                    if (a == 'gallery') await _pickHeader();
                    if (a == 'remove') {
                      setState(() {
                        _header = null;
                        _headerRemoved = true;
                      });
                    }
                  },
                  child: Container(
                    height: 124,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: c.isDark ? c.cardAlt : c.surfaceLow,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: c.border.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_header != null && _header!.isNotEmpty)
                          (_header!.startsWith('http://') ||
                                  _header!.startsWith('https://') ||
                                  _header!.startsWith('blob:') ||
                                  _header!.startsWith('data:')
                              ? Image.network(_header!, fit: BoxFit.cover)
                              : Image.file(File(_header!), fit: BoxFit.cover))
                        else
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  c.primary.withValues(alpha: 0.28),
                                  c.isDark ? c.cardAlt : c.surfaceLow,
                                ],
                              ),
                            ),
                          ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF000000)
                                .withValues(alpha: _header != null ? 0.24 : 0.0),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: ShapeDecoration(
                              color: const Color(0xFF000000)
                                  .withValues(alpha: 0.45),
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.image,
                                  size: 13,
                                  color: Palette.neutral0,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _header != null ? 'Capa' : 'Adicionar capa',
                                  style: T.micro.copyWith(
                                    color: Palette.neutral0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 78,
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
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: c.card,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        children: [
                          Avatar(path: _avatar, name: _name.text, size: 86),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: c.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: c.card, width: 2),
                              ),
                              child: Icon(
                                LucideIcons.camera,
                                size: 15,
                                color: c.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
          else
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
            bg: c.isDark ? c.cardAlt : c.surfaceLow,
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
    final maxW = isWide(context) ? 820.0 : 640.0;
    final pad = sidePadding(context, maxWidth: maxW);

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
                                'Versão 1.6',
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
