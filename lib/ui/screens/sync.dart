import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../data/drive_sync.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

/// Tela de Sincronização com o Google Drive (`appDataFolder`).
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sync = context.sync;
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
                          child: BarTitle('Sincronização', progress: progress),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.xl),
                    sliver: SliverList.list(
                      children: [
                        LargeTitle('Sincronização', style: T.pageTitle),
                        const SizedBox(height: Space.xs),
                        Text(
                          'Backup privado e automático no seu Google Drive',
                          style: T.label.copyWith(color: c.textSecondary),
                        ),
                        const SizedBox(height: Space.lg),

                        // ── Card principal de conexão / status
                        if (!sync.isConnected)
                          _DisconnectedCard(sync: sync)
                        else
                          _ConnectedCard(sync: sync),

                        // ── Banner de conflito (quando os dois lados mudaram)
                        if (sync.pendingConflict != null) ...[
                          const SizedBox(height: Space.md),
                          _ConflictCard(
                            conflict: sync.pendingConflict!,
                            sync: sync,
                          ),
                        ],

                        // ── Banner de erro
                        if (sync.lastError != null) ...[
                          const SizedBox(height: Space.md),
                          Container(
                            padding: const EdgeInsets.all(Space.base),
                            decoration: ShapeDecoration(
                              color: c.negativeSoft,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(
                                  Space.radiusCard,
                                ),
                                side: BorderSide(
                                  color: c.negative.withValues(alpha: 0.28),
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  LucideIcons.triangleAlert,
                                  size: 18,
                                  color: c.negative,
                                ),
                                const SizedBox(width: Space.sm),
                                Expanded(
                                  child: Text(
                                    sync.lastError!,
                                    style: T.small.copyWith(color: c.negative),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ── Configurações e ações manuais
                        if (sync.isConnected) ...[
                          ListGroup(
                            title: 'Automático',
                            children: [
                              ListRow(
                                leading: Icon(
                                  LucideIcons.refreshCw,
                                  size: 20,
                                  color: c.textSecondary,
                                ),
                                title: 'Sincronização automática',
                                subtitle:
                                    'Envia alterações e busca atualizações sozinho',
                                trailing: SpringSwitch(
                                  value: sync.autoSync,
                                  label: 'Sincronização automática',
                                  onChanged: sync.setAutoSync,
                                ),
                              ),
                              if (sync.autoSync)
                                ListRow(
                                  leading: Icon(
                                    LucideIcons.clock,
                                    size: 20,
                                    color: c.textSecondary,
                                  ),
                                  title: 'Frequência',
                                  value: sync.frequency.label,
                                  arrow: true,
                                  onTap: () => _pickFrequency(context, sync),
                                ),
                            ],
                          ),
                          ListGroup(
                            title: 'Ações',
                            children: [
                              ListRow(
                                leading: Icon(
                                  LucideIcons.cloudDownload,
                                  size: 20,
                                  color: c.textSecondary,
                                ),
                                title: 'Restaurar do Google Drive',
                                subtitle:
                                    'Substitui os dados deste aparelho pela cópia da nuvem',
                                arrow: true,
                                onTap: sync.isSyncing
                                    ? null
                                    : () => _confirmPull(context, sync),
                              ),
                              ListRow(
                                leading: Icon(
                                  LucideIcons.cloudUpload,
                                  size: 20,
                                  color: c.textSecondary,
                                ),
                                title: 'Enviar backup agora',
                                subtitle:
                                    'Salva uma nova cópia deste aparelho no Drive',
                                arrow: true,
                                onTap: sync.isSyncing
                                    ? null
                                    : () => _push(context, sync),
                              ),
                              ListRow(
                                leading: Icon(
                                  LucideIcons.logOut,
                                  size: 20,
                                  color: c.negative,
                                ),
                                title: 'Desconectar conta Google',
                                titleColor: c.negative,
                                subtitle:
                                    'Seus dados continuam salvos aqui e no Drive',
                                onTap: sync.isSyncing
                                    ? null
                                    : () => _confirmDisconnect(context, sync),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: Space.lg),
                        Text(
                          'O maré guarda apenas um arquivo privado na pasta oculta do app no seu Google Drive e não acessa nenhum outro arquivo seu.',
                          textAlign: TextAlign.center,
                          style: T.small.copyWith(color: c.textTertiary),
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

  Future<void> _pickFrequency(BuildContext context, SyncService sync) async {
    final chosen = await actionSheet<SyncFrequency>(
      context,
      title: 'Frequência da sincronização',
      message: 'Com que frequência o maré verifica atualizações no Drive.',
      actions: [
        for (final f in SyncFrequency.values)
          SheetAction(
            f.label,
            f,
            icon: f == sync.frequency ? LucideIcons.check : LucideIcons.clock,
          ),
      ],
    );
    if (chosen != null) sync.setFrequency(chosen);
  }

  Future<void> _confirmPull(BuildContext context, SyncService sync) async {
    final ok = await confirm(
      context,
      title: 'Restaurar do Google Drive?',
      message:
          'Os dados salvos neste aparelho serão substituídos pela cópia mais recente do seu Google Drive.',
      action: 'Restaurar',
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    final res = await sync.pullNow();
    if (!context.mounted) return;
    toast(
      context,
      res.message,
      icon: res.ok ? LucideIcons.check : LucideIcons.triangleAlert,
    );
  }

  Future<void> _push(BuildContext context, SyncService sync) async {
    final res = await sync.pushNow();
    if (!context.mounted) return;
    toast(
      context,
      res.message,
      icon: res.ok ? LucideIcons.check : LucideIcons.triangleAlert,
    );
  }

  Future<void> _confirmDisconnect(
    BuildContext context,
    SyncService sync,
  ) async {
    final ok = await confirm(
      context,
      title: 'Desconectar Google Drive?',
      message:
          'A sincronização automática será pausada. Os dados deste celular e a cópia no Drive continuam intactos.',
      action: 'Desconectar',
    );
    if (!ok || !context.mounted) return;
    await sync.disconnect();
    if (context.mounted) toast(context, 'Conta desconectada');
  }
}

class _DisconnectedCard extends StatelessWidget {
  final SyncService sync;
  const _DisconnectedCard({required this.sync});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(LucideIcons.cloud, c.primary, size: 46),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Drive',
                      style: T.headline.copyWith(color: c.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Desconectado',
                      style: T.small.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Text(
            'Conecte sua conta Google para manter uma cópia automática e criptografada em trânsito no seu próprio Drive.',
            style: T.small.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.base),
          Builder(
            builder: (_) {
              final (btnBg, btnFg) = softActionTone(
                c.palette.primary[500],
                isDark: c.isDark,
              );
              return PillButton(
                sync.isSyncing ? 'Conectando…' : 'Conectar Google Drive',
                icon: LucideIcons.cloudUpload,
                background: btnBg,
                foreground: btnFg,
                onTap: sync.isSyncing
                    ? null
                    : () async {
                        final res = await sync.connect();
                        if (!context.mounted) return;
                        toast(
                          context,
                          res.message,
                          icon: res.ok
                              ? LucideIcons.check
                              : LucideIcons.triangleAlert,
                        );
                      },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  final SyncService sync;
  const _ConnectedCard({required this.sync});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tagColor = sync.pendingConflict != null
        ? c.accentWarm
        : (sync.status == SyncStatus.error ? c.negative : c.positive);
    final tagLabel = sync.isSyncing
        ? 'Sincronizando'
        : sync.pendingConflict != null
        ? 'Conflito'
        : sync.status == SyncStatus.error
        ? 'Erro'
        : 'Conectado';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GoogleAvatar(
                photoUrl: sync.accountPhotoUrl,
                fallbackName: sync.accountName ?? sync.accountEmail ?? 'G',
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sync.accountName?.isNotEmpty == true
                          ? sync.accountName!
                          : 'Conta Google',
                      style: T.bodyStrong.copyWith(color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      sync.accountEmail ?? '',
                      style: T.small.copyWith(color: c.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              Tag(
                tagLabel,
                bg: tagColor.withValues(alpha: c.isDark ? 0.2 : 0.14),
                fg: c.tone(tagColor, min: 4.5),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Icon(LucideIcons.clock, size: 14, color: c.textTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _syncMeta(sync),
                  style: T.small.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.base),
          Builder(
            builder: (_) {
              final (btnBg, btnFg) = softActionTone(
                c.palette.primary[500],
                isDark: c.isDark,
              );
              return PillButton(
                sync.isSyncing ? 'Sincronizando…' : 'Sincronizar agora',
                icon: LucideIcons.refreshCw,
                background: btnBg,
                foreground: btnFg,
                onTap: sync.isSyncing
                    ? null
                    : () async {
                        final res = await sync.syncNow();
                        if (!context.mounted) return;
                        toast(
                          context,
                          res.message,
                          icon: res.ok
                              ? LucideIcons.check
                              : LucideIcons.triangleAlert,
                        );
                      },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  final SyncConflict conflict;
  final SyncService sync;
  const _ConflictCard({required this.conflict, required this.sync});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fmt = DateFormat("dd/MM 'às' HH:mm", 'pt_BR');
    final localStr = conflict.localUpdatedAt == null
        ? 'agora'
        : fmt.format(conflict.localUpdatedAt!.toLocal());
    final remoteStr = conflict.remoteUpdatedAt == null
        ? 'desconhecida'
        : fmt.format(conflict.remoteUpdatedAt!.toLocal());
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.gitCompare, size: 20, color: c.accentWarm),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  'Escolha qual cópia manter',
                  style: T.bodyStrong.copyWith(color: c.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(
            'Este celular ($localStr) e o Google Drive ($remoteStr) têm versões diferentes.',
            style: T.small.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  'Usar da nuvem',
                  kind: BtnKind.ghost,
                  height: 44,
                  onTap: sync.isSyncing
                      ? null
                      : () async {
                          final res = await sync.pullNow();
                          if (context.mounted) toast(context, res.message);
                        },
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: PillButton(
                  'Manter celular',
                  height: 44,
                  onTap: sync.isSyncing
                      ? null
                      : () async {
                          final res = await sync.pushNow();
                          if (context.mounted) toast(context, res.message);
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoogleAvatar extends StatelessWidget {
  final String? photoUrl;
  final String fallbackName;
  const _GoogleAvatar({required this.photoUrl, required this.fallbackName});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fallback = Avatar(name: fallbackName, size: 44);
    if (photoUrl == null || photoUrl!.isEmpty) return fallback;
    return SizedBox(
      width: 44,
      height: 44,
      child: ClipOval(
        child: Image.network(
          photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : Container(color: c.cardAlt),
        ),
      ),
    );
  }
}

/// Texto amigável resumindo a última sincronização (usado no Perfil e na tela de Sync).
String syncSummaryLabel(SyncService sync) {
  if (!sync.isConnected) return 'Backup automático no Google Drive';
  if (sync.isSyncing) return 'Sincronizando com o Google Drive…';
  if (sync.pendingConflict != null) return 'Conflito pendente · toque para resolver';
  if (sync.lastSyncedAt == null) return 'Google Drive conectado';
  return 'Sincronizado ${_relativeTime(sync.lastSyncedAt!)}';
}

String _syncMeta(SyncService sync) {
  final parts = <String>[
    sync.lastSyncedAt == null
        ? 'Ainda não sincronizado'
        : 'Última sincronização: ${_relativeTime(sync.lastSyncedAt!)}',
    if (sync.remoteSizeBytes != null) _fmtBytes(sync.remoteSizeBytes!),
  ];
  return parts.join(' · ');
}

String _relativeTime(DateTime utc) {
  final diff = DateTime.now().toUtc().difference(utc);
  if (diff.inSeconds < 45) return 'agora mesmo';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  return DateFormat("dd/MM 'às' HH:mm", 'pt_BR').format(utc.toLocal());
}

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
