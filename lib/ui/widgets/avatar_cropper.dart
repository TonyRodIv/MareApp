import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/theme.dart';
import 'kit.dart';

/// Abre uma tela limpa para o usuário ajustar zoom e posição da foto de perfil
/// dentro de um recorte circular, salvando a imagem recortada em disco.
/// Retorna o caminho do arquivo salvo ou `null` se cancelar.
Future<String?> cropAvatarPhoto(BuildContext context, File source) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AvatarCropperPage(source: source),
    ),
  );
}

class _AvatarCropperPage extends StatefulWidget {
  final File source;
  const _AvatarCropperPage({required this.source});

  @override
  State<_AvatarCropperPage> createState() => _AvatarCropperPageState();
}

class _AvatarCropperPageState extends State<_AvatarCropperPage> {
  final _captureKey = GlobalKey();
  final _transform = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _saveCrop() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final dest = File(
        '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await dest.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, dest.path);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        toast(
          context,
          'Não foi possível recortar essa foto',
          icon: LucideIcons.triangleAlert,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.sizeOf(context);
    final cropSize = (size.width - Space.gutter * 2).clamp(220.0, 320.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.sm,
                  Space.base,
                  Space.sm,
                ),
                child: Row(
                  children: [
                    Pressable(
                      semanticLabel: 'Cancelar',
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: const EdgeInsets.all(Space.sm),
                        child: Text(
                          'Cancelar',
                          style: T.body.copyWith(color: Palette.neutral300),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Ajustar foto',
                        textAlign: TextAlign.center,
                        style: T.bodyStrong.copyWith(color: Palette.neutral0),
                      ),
                    ),
                    Pressable(
                      semanticLabel: 'Resetar zoom',
                      onTap: () => _transform.value = Matrix4.identity(),
                      child: const Padding(
                        padding: EdgeInsets.all(Space.sm),
                        child: Icon(
                          LucideIcons.rotateCcw,
                          size: 20,
                          color: Palette.neutral300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: cropSize,
                        height: cropSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipOval(
                              child: RepaintBoundary(
                                key: _captureKey,
                                child: ColoredBox(
                                  color: const Color(0xFF141416),
                                  child: SizedBox(
                                    width: cropSize,
                                    height: cropSize,
                                    child: InteractiveViewer(
                                      transformationController: _transform,
                                      minScale: 1.0,
                                      maxScale: 4.5,
                                      boundaryMargin: EdgeInsets.all(
                                        cropSize * 0.45,
                                      ),
                                      child: Image.file(
                                        widget.source,
                                        width: cropSize,
                                        height: cropSize,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: Container(
                                width: cropSize,
                                height: cropSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Palette.neutral0.withValues(
                                      alpha: 0.45,
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      Text(
                        'Arraste e faça pinça para enquadrar seu rosto',
                        style: T.small.copyWith(color: Palette.neutral300),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  Space.base,
                ),
                child: PillButton(
                  _saving ? 'Salvando…' : 'Usar foto',
                  icon: LucideIcons.check,
                  background: c.primary,
                  foreground: c.onPrimary,
                  onTap: _saving ? null : _saveCrop,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
