import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/drive_sync.dart';
import '../../data/store.dart';
import '../widgets/kit.dart';

String _fileName() {
  final d = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'mare-backup-${d.year}-${two(d.month)}-${two(d.day)}.json';
}

enum _ExportWay { save, share, copy }

/// Exporta todos os dados num arquivo .json.
Future<void> exportBackupFlow(BuildContext context) async {
  final store = context.storeRead;
  final way = await actionSheet<_ExportWay>(
    context,
    title: 'Exportar backup',
    message:
        'Gera um arquivo com todos os seus dados. Guarde num lugar seguro.',
    actions: const [
      SheetAction(
        'Salvar em arquivo',
        _ExportWay.save,
        icon: LucideIcons.download,
      ),
      SheetAction('Compartilhar…', _ExportWay.share, icon: LucideIcons.share),
      SheetAction('Copiar como texto', _ExportWay.copy, icon: LucideIcons.copy),
    ],
  );
  if (way == null || !context.mounted) return;
  final json = store.exportJson();
  final bytes = Uint8List.fromList(utf8.encode(json));
  try {
    switch (way) {
      case _ExportWay.save:
        final uri = await FilePicker.saveFile(
          fileName: _fileName(),
          bytes: bytes,
          mimeType: 'application/json',
          dialogTitle: 'Salvar backup',
        );
        if (uri != null && context.mounted) toast(context, 'Backup salvo');
      case _ExportWay.share:
        final box = context.findRenderObject() as RenderBox?;
        final origin = (box != null && box.attached)
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${_fileName()}');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            subject: 'Backup do maré',
            sharePositionOrigin: origin,
          ),
        );
      case _ExportWay.copy:
        await Clipboard.setData(ClipboardData(text: json));
        if (context.mounted) toast(context, 'Backup copiado');
    }
  } catch (e) {
    if (context.mounted)
      toast(
        context,
        'Não foi possível exportar agora',
        icon: LucideIcons.triangleAlert,
      );
  }
}

enum _ImportWay { drive, file, paste }

/// Importa backup do maré (ou do FinApp web antigo) do Google Drive, arquivo ou texto.
Future<void> importBackupFlow(BuildContext context) async {
  final store = context.storeRead;
  final sync = context.syncRead;
  final hasData =
      store.data.expenses.isNotEmpty ||
      store.data.boxes.isNotEmpty ||
      store.data.salaries.isNotEmpty;
  final way = await actionSheet<_ImportWay>(
    context,
    title: 'Importar backup',
    message: hasData
        ? 'Os dados atuais deste celular serão substituídos pelos do backup.'
        : 'Restaure do Google Drive ou de um arquivo/texto do maré.',
    actions: [
      if (sync.isSupportedPlatform)
        const SheetAction(
          'Restaurar do Google Drive',
          _ImportWay.drive,
          icon: LucideIcons.cloudDownload,
        ),
      const SheetAction(
        'Escolher arquivo',
        _ImportWay.file,
        icon: LucideIcons.fileUp,
      ),
      const SheetAction(
        'Colar texto copiado',
        _ImportWay.paste,
        icon: LucideIcons.clipboardPaste,
      ),
    ],
  );
  if (way == null || !context.mounted) return;

  if (way == _ImportWay.drive) {
    if (hasData) {
      final ok = await confirm(
        context,
        title: 'Substituir dados?',
        message: 'Tudo o que está neste celular será trocado pela cópia do Google Drive.',
        action: 'Restaurar',
      );
      if (!ok || !context.mounted) return;
    }
    final res = sync.isConnected ? await sync.pullNow() : await sync.connect();
    if (!context.mounted) return;
    toast(
      context,
      res.message,
      icon: res.ok ? LucideIcons.check : LucideIcons.triangleAlert,
    );
    return;
  }

  String? raw;
  try {
    if (way == _ImportWay.file) {
      final picked = await FilePicker.pickFile(
        type: FileType.any,
        dialogTitle: 'Escolher backup',
      );
      if (picked == null) return;
      raw = utf8.decode(await picked.readAsBytes(), allowMalformed: true);
    } else {
      raw = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    }
  } catch (_) {
    raw = null;
  }
  if (!context.mounted) return;
  if (raw == null || raw.trim().isEmpty) {
    toast(
      context,
      way == _ImportWay.paste
          ? 'Nada copiado para colar'
          : 'Não consegui abrir o arquivo',
      icon: LucideIcons.triangleAlert,
    );
    return;
  }
  if (hasData) {
    final ok = await confirm(
      context,
      title: 'Substituir dados?',
      message: 'Tudo o que está neste celular será trocado pelo backup.',
      action: 'Substituir',
    );
    if (!ok || !context.mounted) return;
  }
  final err = store.importJson(raw);
  if (!context.mounted) return;
  toast(
    context,
    err ?? 'Backup importado',
    icon: err == null ? LucideIcons.check : LucideIcons.triangleAlert,
  );
}
