import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';

// ── Toque com feedback (escala + háptico) ───────────────────

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final String? semanticLabel;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.haptic = true,
    this.semanticLabel,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
          child: AnimatedOpacity(opacity: enabled ? 1 : 0.45, duration: const Duration(milliseconds: 120), child: widget.child),
        ),
      ),
    );
  }
}

// ── Botões ──────────────────────────────────────────────────

enum BtnKind { primary, secondary, ghost, outline, danger }

class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool expand;
  final double height;
  const PillButton(
    this.label, {
    super.key,
    this.icon,
    this.trailingIcon,
    this.onTap,
    this.kind = BtnKind.primary,
    this.expand = true,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border) = switch (kind) {
      BtnKind.primary => (c.primary, c.onPrimary, null),
      BtnKind.secondary => (c.secondary, c.onSecondary, null),
      BtnKind.ghost => (c.card, c.text, null),
      BtnKind.outline => (const Color(0x00000000), c.primary, Border.all(color: c.primary.withValues(alpha: 0.4), width: 1.5)),
      BtnKind.danger => (c.negativeSoft, c.negative, null),
    };
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: kind == BtnKind.secondary ? c.accentWarm : fg),
          const SizedBox(width: Space.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: T.label.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: Space.sm),
          Icon(trailingIcon, size: 18, color: fg),
        ],
      ],
    );
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: Space.base),
        decoration: BoxDecoration(color: bg, border: border, borderRadius: BorderRadius.circular(height / 2)),
        child: content,
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? bg;
  final Color? fg;
  final String? label;
  const RoundIconButton(this.icon, {super.key, this.onTap, this.size = 48, this.bg, this.fg, this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg ?? c.card, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.46, color: fg ?? c.text),
      ),
    );
  }
}

/// Botão "voltar" do topo das telas (chevron, como no Figma).
class BackChevron extends StatelessWidget {
  final VoidCallback? onTap;
  const BackChevron({super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
    semanticLabel: 'Voltar',
    onTap: onTap ?? () => Navigator.of(context).maybePop(),
    child: SizedBox(width: 44, height: 44, child: Icon(LucideIcons.chevronLeft, color: context.c.text, size: 28)),
  );
}

// ── Chips / tags ────────────────────────────────────────────

class ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final Color? dot;
  const ChipButton(this.label, {super.key, this.onTap, this.selected = false, this.icon, this.dot});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: selected ? c.primary : c.card, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            if (icon != null) ...[Icon(icon, size: 16, color: selected ? c.onPrimary : c.text), const SizedBox(width: 6)],
            Text(
              label,
              style: T.label.copyWith(fontWeight: FontWeight.w600, color: selected ? c.onPrimary : c.text),
            ),
          ],
        ),
      ),
    );
  }
}

class Tag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? bg;
  final Color? fg;
  const Tag(this.label, {super.key, this.icon, this.bg, this.fg});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = fg ?? c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg ?? c.cardAlt, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(
            label,
            style: T.small.copyWith(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ── Cards ───────────────────────────────────────────────────

/// Card padrão do dashboard: título + seta ↗ que leva ao detalhe.
class AppCard extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final bool expandChild;
  const AppCard({
    super.key,
    this.title,
    this.titleWidget,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hasHeader = title != null || titleWidget != null;
    final body = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(Space.radiusCard),
        border: Border.all(color: c.border.withValues(alpha: c.isDark ? 0.5 : 0.65)),
        boxShadow: c.isDark ? null : const [BoxShadow(color: Color(0x0A0A0D12), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (hasHeader)
            Row(
              children: [
                Expanded(
                  child:
                      titleWidget ??
                      Text(
                        title!,
                        style: T.label.copyWith(color: c.text, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                ),
                if (onTap != null) Icon(LucideIcons.arrowUpRight, size: 18, color: c.textSecondary),
              ],
            ),
          if (hasHeader) const SizedBox(height: Space.md),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
    return onTap == null ? body : Pressable(onTap: onTap, scale: 0.985, child: body);
  }
}

/// Valor monetário com "R$" no mesmo tamanho e alinhamento do número.
class MoneyText extends StatelessWidget {
  final Cents cents;
  final TextStyle style;
  final bool hidden;
  final Color? color;
  final bool signed;
  const MoneyText(this.cents, {super.key, required this.style, this.hidden = false, this.color, this.signed = false});

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.c.text;
    final neg = cents < 0;
    final sign = neg ? '−' : (signed && cents > 0 ? '+' : '');
    final formatted = '${sign}R\$ ${fmtNumber(cents.abs(), hidden: hidden)}';
    return Semantics(
      label: hidden ? 'Valor oculto' : fmtMoney(cents),
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          formatted,
          style: style.copyWith(color: col, fontFeatures: const [ui.FontFeature.tabularFigures()]),
          maxLines: 1,
        ),
      ),
    );
  }
}

// ── Segmented (Cupertino estilizado) ────────────────────────

class Segmented<V extends Object> extends StatelessWidget {
  final V value;
  final Map<V, String> options;
  final ValueChanged<V> onChanged;
  const Segmented({super.key, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<V>(
        groupValue: value,
        backgroundColor: c.card,
        thumbColor: c.primary,
        padding: const EdgeInsets.all(4),
        onValueChanged: (v) {
          if (v == null) return;
          HapticFeedback.selectionClick();
          onChanged(v);
        },
        children: {
          for (final e in options.entries)
            e.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                e.value,
                style: T.label.copyWith(
                  color: e.key == value ? c.onPrimary : c.textSecondary,
                  fontWeight: e.key == value ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
        },
      ),
    );
  }
}

// ── Campos ──────────────────────────────────────────────────

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: T.label.copyWith(color: context.c.text)),
  );
}

class AppField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool autofocus;
  final TextInputAction? action;
  final Widget? prefix;
  final Widget? suffix;
  final int? maxLength;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;
  const AppField({
    super.key,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.autofocus = false,
    this.action,
    this.prefix,
    this.suffix,
    this.maxLength,
    this.focusNode,
    this.formatters,
    this.capitalization = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      autofocus: autofocus,
      textInputAction: action,
      maxLength: maxLength,
      inputFormatters: formatters,
      textCapitalization: capitalization,
      keyboardAppearance: c.brightness,
      cursorColor: c.accent,
      style: T.body.copyWith(color: c.text),
      placeholderStyle: T.body.copyWith(color: c.textTertiary),
      padding: const EdgeInsets.symmetric(horizontal: Space.base, vertical: Space.base),
      prefix: prefix == null ? null : Padding(padding: const EdgeInsets.only(left: Space.base), child: prefix),
      suffix: suffix == null ? null : Padding(padding: const EdgeInsets.only(right: Space.md), child: suffix),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Space.radiusField),
        border: Border.all(color: c.border.withValues(alpha: c.isDark ? 0.55 : 0.75)),
      ),
    );
  }
}

/// Linha clicável que parece um campo (abre picker/sheet).
class SelectField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? leading;
  const SelectField({super.key, this.value, required this.placeholder, required this.onTap, this.leading});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(Space.radiusField)),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Text(
                value ?? placeholder,
                style: T.body.copyWith(color: value == null ? c.textTertiary : c.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(LucideIcons.chevronDown, size: 18, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Ícone de categoria / caixinha ───────────────────────────

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool solid;
  const IconBadge(this.icon, this.color, {super.key, this.size = 44, this.solid = false});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: solid ? color : color.withValues(alpha: context.c.isDark ? 0.18 : 0.14),
      borderRadius: BorderRadius.circular(size * 0.32),
    ),
    child: Icon(icon, size: size * 0.48, color: solid ? Palette.neutral0 : color),
  );
}

// ── Avatar ──────────────────────────────────────────────────

class Avatar extends StatelessWidget {
  final String? path;
  final String name;
  final double size;
  const Avatar({super.key, this.path, required this.name, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? ''
        : name.trim().split(RegExp(r'\s+')).take(2).map((p) => p.characters.first.toUpperCase()).join();
    final file = path == null ? null : File(path!);
    final hasImg = file != null && file.existsSync();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.brandDeep),
      child: hasImg
          ? Image.file(file, fit: BoxFit.cover, width: size, height: size)
          : Center(
              child: initials.isEmpty
                  ? Icon(LucideIcons.user, color: Palette.brandSky, size: size * 0.45)
                  : Text(
                      initials,
                      style: T.bodyStrong.copyWith(fontSize: size * 0.36, color: Palette.brandSky),
                    ),
            ),
    );
  }
}

// ── Marca maré. ─────────────────────────────────────────────

/// Símbolo: círculo com a onda (identidade visual).
class MareMark extends StatelessWidget {
  final double size;
  final bool onDark;
  const MareMark({super.key, this.size = 32, this.onDark = true});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MarkPainter(onDark));
}

class _MarkPainter extends CustomPainter {
  final bool onDark;
  _MarkPainter(this.onDark);
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    final circle = Path()..addOval(Rect.fromCircle(center: Offset(r, r), radius: r));
    canvas.save();
    canvas.clipPath(circle);
    canvas.drawRect(Offset.zero & s, Paint()..color = onDark ? Palette.brandMist.withValues(alpha: 0.85) : Palette.brandDeep);
    final y = s.height * 0.52;
    Path wave(double dy) => Path()
      ..moveTo(0, y + dy)
      ..cubicTo(s.width * 0.25, y - s.height * 0.12 + dy, s.width * 0.5, y + s.height * 0.12 + dy, s.width * 0.75, y + dy)
      ..quadraticBezierTo(s.width * 0.9, y - s.height * 0.08 + dy, s.width, y - s.height * 0.02 + dy)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(wave(-s.height * 0.03), Paint()..color = Palette.brandDot);
    canvas.drawPath(wave(s.height * 0.02), Paint()..color = onDark ? Palette.brandDeep : Palette.brandSky);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.onDark != onDark;
}

/// Wordmark "maré." com o ponto em ciano.
class MareWordmark extends StatelessWidget {
  final double size;
  final Color? color;
  const MareWordmark({super.key, this.size = 22, this.color});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'maré',
    excludeSemantics: true,
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'maré',
            style: T.headline.copyWith(fontSize: size, fontWeight: FontWeight.w700, color: color ?? context.c.text, letterSpacing: -0.3),
          ),
          TextSpan(
            text: '.',
            style: T.headline.copyWith(fontSize: size, fontWeight: FontWeight.w700, color: Palette.brandDot),
          ),
        ],
      ),
    ),
  );
}

// ── Fundo com brilho gradual (sem corte abrupto) ────────────

class GlowBackground extends StatelessWidget {
  final double height;
  final Color? tint;
  const GlowBackground({super.key, this.height = 540, this.tint});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = tint ?? c.primary;
    return IgnorePointer(
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xD9FFFFFF),
            Color(0x73FFFFFF),
            Color(0x1FFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.28, 0.56, 0.80, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.75, -1.05),
              radius: 1.45,
              colors: [
                a.withValues(alpha: c.isDark ? 0.44 : 0.28),
                a.withValues(alpha: c.isDark ? 0.18 : 0.10),
                a.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          foregroundDecoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-1.0, -0.7),
              radius: 1.25,
              colors: [
                c.accentWarm.withValues(alpha: c.isDark ? 0.18 : 0.12),
                c.accentWarm.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Progressive Blur real via GLSL Fragment Shader (Impeller) ─

/// Blur progressivo contínuo por pixel usando [ui.ImageFilter.shader] (1 única passagem na GPU).
/// O raio do desfoque cresce suavemente de 0px até [maxSigma] seguindo curva quadrática,
/// sem degraus nem empilhamento de BackdropFilters. Em ambientes sem suporte a shader filter
/// (ex.: testes unitários ou fallback Skia), degrada de forma segura para gradiente suave.
class ProgressiveBlur extends StatefulWidget {
  final AxisDirection direction; // down = topo->baixo, up = baixo->topo
  final double maxSigma;
  final double tintOpacity;
  final Color? tint;
  const ProgressiveBlur({
    super.key,
    required this.direction,
    this.maxSigma = 20,
    this.tintOpacity = 0.62,
    this.tint,
  });

  static ui.FragmentProgram? _program;
  static bool _loadAttempted = false;

  static Future<void> preload() async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/progressive_blur.frag');
    } catch (_) {
      _program = null;
    }
  }

  @override
  State<ProgressiveBlur> createState() => _ProgressiveBlurState();
}

class _ProgressiveBlurState extends State<ProgressiveBlur> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _initShader();
  }

  Future<void> _initShader() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    if (ProgressiveBlur._program == null && !ProgressiveBlur._loadAttempted) {
      await ProgressiveBlur.preload();
    }
    final prog = ProgressiveBlur._program;
    if (prog != null && mounted) {
      setState(() => _shader = prog.fragmentShader());
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final baseColor = widget.tint ?? c.bg;
    final fromTop = widget.direction == AxisDirection.down;
    final begin = fromTop ? Alignment.topCenter : Alignment.bottomCenter;
    final end = fromTop ? Alignment.bottomCenter : Alignment.topCenter;

    final scrim = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            baseColor.withValues(alpha: widget.tintOpacity),
            baseColor.withValues(alpha: widget.tintOpacity * 0.55),
            baseColor.withValues(alpha: widget.tintOpacity * 0.16),
            baseColor.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.40, 0.74, 1.0],
        ),
      ),
    );

    final shader = _shader;
    if (shader == null || !ui.ImageFilter.isShaderFilterSupported) {
      // Fallback (web / Skia): sem shader, simula o blur progressivo com faixas
      // de BackdropFilter cujo sigma cai até 0 na borda interna. Assim o desfoque
      // chega a sumir de verdade, em vez de ficar num sigma fixo com só o tint
      // esmaecendo.
      const strips = 16;
      return IgnorePointer(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(builder: (context, box) {
                final h = box.maxHeight;
                final stripH = h / strips;
                return Stack(children: [
                  for (var i = 0; i < strips; i++)
                    () {
                      // t = 1 na borda externa, 0 na interna
                      final centre = (i + 0.5) / strips;
                      final t = fromTop ? 1 - centre : centre;
                      final sigma = widget.maxSigma * 0.8 * t * t * t;
                      if (sigma < 0.4) return const SizedBox.shrink();
                      return Positioned(
                        left: 0,
                        right: 0,
                        top: i * stripH,
                        height: stripH + 0.5,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      );
                    }(),
                ]);
              }),
              scrim,
            ],
          ),
        ),
      );
    }

    // Uniformes após u_size (injetado pelo Impeller nos índices 0 e 1):
    // índice 2 = u_max_radius, índice 3 = u_direction (0 = top->bottom, 1 = bottom->top).
    shader.setFloat(2, widget.maxSigma);
    shader.setFloat(3, fromTop ? 0.0 : 1.0);

    return IgnorePointer(
      child: RepaintBoundary(
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.shader(shader),
            child: scrim,
          ),
        ),
      ),
    );
  }
}

/// Top bar fixa estilo Cupertino com progressive blur ao rolar.
class PinnedCupertinoBar extends StatelessWidget {
  final double height;
  final double? maxWidth;
  final Widget Function(BuildContext context, double progress) builder;
  const PinnedCupertinoBar({super.key, this.height = 64, this.maxWidth, required this.builder});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedBarDelegate(top: top, height: height, maxWidth: maxWidth, builder: builder),
    );
  }
}

class _PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  final double top;
  final double height;
  final double? maxWidth;
  final Widget Function(BuildContext context, double progress) builder;
  _PinnedBarDelegate({required this.top, required this.height, this.maxWidth, required this.builder});

  @override
  double get minExtent => top + height;

  @override
  double get maxExtent => top + height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = context.c;
    final progress = overlapsContent ? 1.0 : (shrinkOffset / 24).clamp(0.0, 1.0);
    final pad = maxWidth == null ? sidePadding(context) : sidePadding(context, maxWidth: maxWidth!);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        if (progress > 0.01)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: -14,
            child: ProgressiveBlur(
              direction: AxisDirection.down,
              maxSigma: 18,
              tintOpacity: c.isDark ? 0.56 : 0.76,
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, top + Space.sm, pad, Space.sm),
          child: builder(context, progress),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_PinnedBarDelegate old) => old.top != top || old.height != height || old.maxWidth != maxWidth;
}

// ── Estado vazio ────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: Space.xl, horizontal: Space.lg),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(Space.radiusCard),
        border: Border.all(color: c.border.withValues(alpha: c.isDark ? 0.5 : 0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, color: c.accent, size: 24),
          ),
          const SizedBox(height: Space.base),
          Text(
            title,
            style: T.bodyStrong.copyWith(color: c.text),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              message!,
              style: T.label.copyWith(color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: Space.lg),
            PillButton(action!, onTap: onAction, expand: false, height: 48),
          ],
        ],
      ),
    );
  }
}

// ── Diálogos e sheets (Cupertino moderno) ───────────────────

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
  bool destructive = true,
}) async {
  final r = await _showFloatingModal<bool>(
    context,
    builder: (ctx) {
      final c = ctx.c;
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(Space.md, 0, Space.md, (bottom > 0 ? bottom : Space.md) + Space.xs),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(32),
                border: c.isDark ? Border.all(color: c.border.withValues(alpha: 0.6)) : null,
                boxShadow: const [BoxShadow(color: Color(0x28000000), blurRadius: 32, offset: Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  Text(
                    title,
                    style: T.headline.copyWith(color: c.text, decoration: TextDecoration.none),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(
                      message,
                      style: T.label.copyWith(color: c.textSecondary, decoration: TextDecoration.none),
                    ),
                  ],
                  const SizedBox(height: Space.lg),
                  Row(
                    children: [
                      Expanded(
                        child: PillButton(
                          'Cancelar',
                          kind: BtnKind.ghost,
                          height: 52,
                          onTap: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: PillButton(
                          action,
                          kind: destructive ? BtnKind.danger : BtnKind.primary,
                          height: 52,
                          onTap: () => Navigator.pop(ctx, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  return r ?? false;
}

class SheetAction<V> {
  final String label;
  final V value;
  final bool destructive;
  final IconData? icon;
  const SheetAction(this.label, this.value, {this.destructive = false, this.icon});
}

/// Rota modal flutuante com blur progressivo rápido na entrada (220ms) e saída (150ms),
/// garantindo que o blur do fundo desapareça imediatamente junto com o sheet.
Future<V?> _showFloatingModal<V>(BuildContext context, {required WidgetBuilder builder}) {
  return Navigator.of(context, rootNavigator: true).push<V>(_FloatingModalRoute<V>(builder: builder));
}

class _FloatingModalRoute<V> extends PopupRoute<V> {
  final WidgetBuilder builder;
  _FloatingModalRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Fechar';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 190);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 130);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Align(alignment: Alignment.bottomCenter, child: builder(context));
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: curve,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: const ColoredBox(color: Color(0x4D000000)),
              ),
            ),
          ),
        ),
        SlideTransition(
          position: Tween(begin: const Offset(0, 0.14), end: Offset.zero).animate(curve),
          child: child,
        ),
      ],
    );
  }
}

/// Bottom sheet flutuante e arredondado (com blur progressivo no fundo, opções limpas sem linhas e botão pill na base).
Future<V?> actionSheet<V>(BuildContext context, {String? title, String? message, required List<SheetAction<V>> actions}) {
  return _showFloatingModal<V>(
    context,
    builder: (ctx) {
      final c = ctx.c;
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(Space.md, 0, Space.md, (bottom > 0 ? bottom : Space.md) + Space.xs),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(32),
                border: c.isDark ? Border.all(color: c.border.withValues(alpha: 0.6)) : null,
                boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 32, offset: Offset(0, 12))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  if (title != null || message != null) ...[
                    const SizedBox(height: Space.base),
                    if (title != null)
                      Text(
                        title,
                        style: T.headline.copyWith(color: c.text, decoration: TextDecoration.none),
                      ),
                    if (message != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        message,
                        style: T.label.copyWith(color: c.textSecondary, decoration: TextDecoration.none),
                      ),
                    ],
                    const SizedBox(height: Space.md),
                  ] else
                    const SizedBox(height: Space.base),
                  for (final a in actions)
                    _FloatingSheetRow(
                      action: a,
                      onTap: () => Navigator.pop(ctx, a.value),
                    ),
                  const SizedBox(height: Space.base),
                  Pressable(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      height: 52,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.isDark ? c.cardAlt : c.text,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        'Fechar',
                        style: T.bodyStrong.copyWith(
                          color: c.isDark ? c.text : Palette.neutral0,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FloatingSheetRow<V> extends StatelessWidget {
  final SheetAction<V> action;
  final VoidCallback onTap;
  const _FloatingSheetRow({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = action.destructive ? c.negative : c.text;
    final iconColor = action.destructive ? c.negative : c.text;
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            if (action.icon != null) ...[
              Icon(action.icon, size: 20, color: iconColor),
              const SizedBox(width: Space.base),
            ],
            Expanded(
              child: Text(
                action.label,
                style: T.body.copyWith(color: fg, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet flutuante e arredondado para formulários e seletores.
Future<V?> showSheet<V>(BuildContext context, {required Widget Function(BuildContext) builder}) {
  return _showFloatingModal<V>(
    context,
    builder: (ctx) {
      final c = ctx.c;
      final mq = MediaQuery.of(ctx);
      final bottom = mq.padding.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(Space.md, Space.xl, Space.md, mq.viewInsets.bottom + (bottom > 0 ? bottom : Space.md)),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 480, maxHeight: mq.size.height * 0.86),
            child: Container(
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(32),
                border: c.isDark ? Border.all(color: c.border.withValues(alpha: 0.6)) : null,
                boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 32, offset: Offset(0, 12))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: Space.md),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  Flexible(child: builder(ctx)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void toast(BuildContext context, String message, {IconData icon = LucideIcons.check}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final c = context.c;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _Toast(message: message, icon: icon, colors: c, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  final String message;
  final IconData icon;
  final AppColors colors;
  final VoidCallback onDone;
  const _Toast({required this.message, required this.icon, required this.colors, required this.onDone});
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void initState() {
    super.initState();
    _a.forward();
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      await _a.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Positioned(
      left: 20,
      right: 20,
      top: MediaQuery.of(context).padding.top + 8,
      child: FadeTransition(
        opacity: _a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(CurvedAnimation(parent: _a, curve: Curves.easeOutCubic)),
          child: Semantics(
            liveRegion: true,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: c.isDark ? Palette.neutral700 : Palette.neutral800,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 18, color: c.accent),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: T.label.copyWith(color: Palette.neutral0, decoration: TextDecoration.none),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho de seção dentro de listas (sem CAIXA ALTA).
class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionHeader(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, Space.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: T.label.copyWith(color: context.c.textSecondary, fontWeight: FontWeight.w600)),
        ),
        ?trailing,
      ],
    ),
  );
}

double clamp01(double v) => math.max(0, math.min(1, v));

// ── Responsivo ──────────────────────────────────────────────

class Breakpoints {
  static const tablet = 600.0;
  static const desktop = 900.0;
}

/// Padding horizontal que centraliza o conteúdo em telas largas.
double sidePadding(BuildContext context, {double maxWidth = 760}) {
  final w = MediaQuery.sizeOf(context).width;
  return math.max(Space.gutter, (w - maxWidth) / 2);
}

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
