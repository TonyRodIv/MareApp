import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/perf.dart';
import '../../data/brands.dart';
import '../../core/color_engine.dart';
import '../../core/theme.dart';
import 'motion.dart' show BlurSwitcher, SpringBuilder, Springs, easeOutExpo;

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
          child: AnimatedOpacity(
            opacity: enabled ? 1 : 0.45,
            duration: const Duration(milliseconds: 120),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ── Botões ──────────────────────────────────────────────────

enum BtnKind { primary, secondary, ghost, outline, danger }

/// Vermelho saturado com contraste ≥ 4.5 contra o texto claro (vermelho 50).
Color dangerFill() => ensureContrast(Palette.red.s600, [Palette.red.s50], 4.5);

/// Gera par (fundo desbotado suave, texto/ícone mais claro/nítido no centro)
/// adaptado ao tema claro e escuro em OKLCH — padrão dos botões principais da
/// Carteira e da Sincronização.
(Color, Color) softActionTone(Color seed, {required bool isDark}) {
  final o = toOklch(seed);
  if (isDark) {
    final bg = fromOklch(0.32, (o.c * 0.48).clamp(0.038, 0.082), o.h);
    final rawFg = fromOklch(0.93, (o.c * 0.16).clamp(0.012, 0.028), o.h);
    final fg = ensureContrast(rawFg, [bg], 7.0);
    return (bg, fg);
  }
  final bg = fromOklch(0.90, (o.c * 0.36).clamp(0.028, 0.064), o.h);
  final rawFg = fromOklch(0.32, (o.c * 0.52).clamp(0.045, 0.095), o.h);
  final fg = ensureContrast(rawFg, [bg], 7.0);
  return (bg, fg);
}

class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onTap;
  final BtnKind kind;
  final bool expand;
  final double height;
  final Color? background;
  final Color? foreground;
  const PillButton(
    this.label, {
    super.key,
    this.icon,
    this.trailingIcon,
    this.onTap,
    this.kind = BtnKind.primary,
    this.expand = true,
    this.height = 56,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg0, fg0, border) = switch (kind) {
      BtnKind.primary => (c.primary, c.onPrimary, null),
      BtnKind.secondary => (c.secondary, c.onSecondary, null),
      BtnKind.ghost => (c.card, c.text, null),
      BtnKind.outline => (
        const Color(0x00000000),
        c.primary,
        Border.all(color: c.primary.withValues(alpha: 0.4), width: 1.5),
      ),
      // Suave: fundo avermelhado contido sem borda, com texto vermelho nítido.
      BtnKind.danger => (c.negativeSoft, c.negative, null),
    };
    final bg = background ?? bg0;
    final fg = foreground ?? fg0;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: kind == BtnKind.secondary && foreground == null
                ? c.accentWarm
                : fg,
          ),
          const SizedBox(width: Space.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: (height <= 48 ? T.labelStrong : T.bodyStrong).copyWith(
              color: fg,
            ),
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
        padding: EdgeInsets.symmetric(
          horizontal: height <= 48 ? Space.md : Space.base,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.circular(height / 2),
        ),
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
  final bool glass;
  const RoundIconButton(
    this.icon, {
    super.key,
    this.onTap,
    this.size = 48,
    this.bg,
    this.fg,
    this.label,
    this.glass = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final iconChild = AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: RotationTransition(
          turns: Tween(begin: -0.16, end: 0.0).animate(anim),
          child: ScaleTransition(scale: anim, child: child),
        ),
      ),
      child: Icon(
        icon,
        key: ValueKey(icon.codePoint),
        size: size * 0.46,
        color: fg ?? c.text,
      ),
    );
    final Widget body;
    if (glass) {
      final perf = context.perf;
      final sigma = 26.0 * perf.glassSigmaFactor;
      final glassBg = bg ??
          (c.isDark
              ? const Color(0xFF16161A).withValues(
                  alpha: perf.allowBlur ? 0.56 : 0.90,
                )
              : const Color(0xFFFFFFFF).withValues(
                  alpha: perf.allowBlur ? 0.62 : 0.92,
                ));
      final circle = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: glassBg,
          shape: BoxShape.circle,
          border: Border.all(
            color: c.isDark
                ? Palette.neutral0.withValues(alpha: 0.12)
                : Palette.neutral950.withValues(alpha: 0.08),
          ),
        ),
        child: iconChild,
      );
      body = perf.allowBlur && sigma >= 1.0
          ? ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: circle,
              ),
            )
          : circle;
    } else {
      body = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg ?? c.card, shape: BoxShape.circle),
        child: iconChild,
      );
    }
    return Pressable(onTap: onTap, semanticLabel: label, child: body);
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
    child: SizedBox(
      width: 44,
      height: 44,
      child: Icon(LucideIcons.chevronLeft, color: context.c.text, size: 28),
    ),
  );
}

// ── Chips / tags ────────────────────────────────────────────

class ChipButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final Color? dot;
  final Color? bg;
  const ChipButton(
    this.label, {
    super.key,
    this.onTap,
    this.selected = false,
    this.icon,
    this.dot,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: ShapeDecoration(
          color: selected ? c.primary : (bg ?? c.card),
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
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
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? c.onPrimary : c.text),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: T.label.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? c.onPrimary : c.text,
              ),
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
      decoration: ShapeDecoration(
        color: bg ?? c.cardAlt,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
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
  final Widget? background;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final bool expandChild;
  final bool bordered;
  const AppCard({
    super.key,
    this.title,
    this.titleWidget,
    required this.child,
    this.background,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.expandChild = false,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hasHeader = title != null || titleWidget != null;
    final content = Padding(
      padding: padding,
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
                        style: T.label.copyWith(
                          color: c.text,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                ),
                if (onTap != null)
                  Icon(
                    LucideIcons.arrowUpRight,
                    size: 18,
                    color: c.textSecondary,
                  ),
              ],
            ),
          if (hasHeader) const SizedBox(height: Space.md),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
    final body = Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        color: color ?? c.card,
        shadows: c.isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0A0A0D12),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Space.radiusCard),
          side: bordered
              ? BorderSide(
                  color: c.border.withValues(alpha: c.isDark ? 0.5 : 0.65),
                )
              : BorderSide.none,
        ),
      ),
      child: background == null
          ? content
          : ClipRSuperellipse(
              borderRadius: BorderRadius.circular(Space.radiusCard),
              child: Stack(
                fit: expandChild ? StackFit.expand : StackFit.passthrough,
                children: [
                  Positioned.fill(child: IgnorePointer(child: background!)),
                  content,
                ],
              ),
            ),
    );
    return onTap == null
        ? body
        : Pressable(onTap: onTap, scale: 0.985, child: body);
  }
}

/// Valor monetário com "R$" no mesmo tamanho e alinhamento do número.
class MoneyText extends StatelessWidget {
  final Cents cents;
  final TextStyle style;
  final bool hidden;
  final Color? color;
  final bool signed;
  const MoneyText(
    this.cents, {
    super.key,
    required this.style,
    this.hidden = false,
    this.color,
    this.signed = false,
  });

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
        child: BlurSwitcher(
          child: Text(
            formatted,
            key: ValueKey(hidden),
            style: style.copyWith(
              color: col,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
            maxLines: 1,
          ),
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
  final Color? trackColor;
  final Color? thumbColor;
  const Segmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.trackColor,
    this.thumbColor,
  });

  /// Barra de abas em formato pílula (altura 40px igual aos chips de filtro,
  /// com 4px de respiro interno e indicador deslizante suave).
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final keys = options.keys.toList();
    final index = keys.indexOf(value).clamp(0, keys.length - 1);
    final track = trackColor ?? (c.isDark ? c.card : c.surfaceLow);
    final thumb = thumbColor ?? (c.isDark ? c.surfaceHigh : c.card);
    return Container(
      height: 40,
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: track,
        shape: const StadiumBorder(),
      ),
      child: LayoutBuilder(
        builder: (ctx, box) {
          final w = box.maxWidth / keys.length;
          return Stack(
            children: [
              SpringBuilder(
                value: index.toDouble(),
                spring: Springs.settle,
                builder: (_, v, _) => Positioned(
                  left: v * w,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: thumb,
                      shadows: c.isDark
                          ? null
                          : const [
                              BoxShadow(
                                color: Color(0x1A0A0D12),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                              BoxShadow(
                                color: Color(0x0F0A0D12),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final k in keys)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: k == value,
                        label: options[k],
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (k == value) return;
                            HapticFeedback.selectionClick();
                            onChanged(k);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 180),
                              style: (k == value ? T.labelStrong : T.label)
                                  .copyWith(
                                    color: k == value ? c.text : c.textSecondary,
                                  ),
                              child: Text(
                                options[k]!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
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
  final bool pill;
  final Color? bg;
  final int? maxLines;
  final int? minLines;
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
    this.pill = false,
    this.bg,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = bg ?? c.card;
    final field = CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      autofocus: autofocus,
      textInputAction: action,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      inputFormatters: formatters,
      textCapitalization: capitalization,
      keyboardAppearance: c.brightness,
      cursorColor: c.accent,
      style: (pill ? T.label : T.body).copyWith(color: c.text),
      placeholderStyle: (pill ? T.label : T.body).copyWith(
        color: c.textSecondary,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: pill ? Space.md : Space.base,
        vertical: pill ? 14 : Space.base,
      ),
      prefix: prefix == null
          ? null
          : Padding(
              padding: EdgeInsets.only(left: pill ? Space.base : Space.base),
              child: prefix,
            ),
      suffix: suffix == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: Space.md),
              child: suffix,
            ),
      decoration: pill
          ? const BoxDecoration(color: Color(0x00000000))
          : BoxDecoration(
              color: fill,
              border: bg != null
                  ? null
                  : Border.all(
                      color: c.border.withValues(alpha: c.isDark ? 0.55 : 0.75),
                    ),
              borderRadius: BorderRadius.circular(Space.radiusField),
            ),
    );
    if (!pill) return field;
    return Container(
      decoration: ShapeDecoration(
        color: fill,
        shape: const StadiumBorder(),
      ),
      child: field,
    );
  }
}

/// Linha clicável que parece um campo (abre picker/sheet).
class SelectField extends StatelessWidget {
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? leading;
  final Color? bg;
  const SelectField({
    super.key,
    this.value,
    required this.placeholder,
    required this.onTap,
    this.leading,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: ShapeDecoration(
          color: bg ?? c.card,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(Space.radiusField),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Text(
                value ?? placeholder,
                style: T.body.copyWith(
                  color: value == null ? c.textTertiary : c.text,
                ),
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

/// Ícone num círculo de cor saturada, com o glifo em branco ou preto (o que
/// contrastar mais). Com `solid: false` volta ao fundo suave tingido.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool solid;
  const IconBadge(
    this.icon,
    this.color, {
    super.key,
    this.size = 44,
    this.solid = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = solid
        ? color
        : color.withValues(alpha: c.isDark ? 0.18 : 0.14);
    final fg = solid
        ? onColor(color, light: Palette.neutral0, dark: const Color(0xFF0A0A0A))
        : c.tone(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: fg),
    );
  }
}

/// Logo da marca (quando o nome do gasto cita uma conhecida) num círculo limpo;
/// senão, escolhe automaticamente um ícone inteligente do Lucide pelo nome ou
/// cai no ícone da categoria. Também usa o fallback quando estiver sem rede.
class BrandLogo extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final double size;
  const BrandLogo({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = smartIconFor(name) ?? icon;
    final fallback = IconBadge(resolvedIcon, color, size: size);
    final spec = brandSpecFor(name);
    if (spec == null) return fallback;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr).round().clamp(32, 256);
    return _BrandLogoImage(
      url: brandLogoUrl(spec.domain),
      size: size,
      cachePx: cachePx,
      background: spec.bg,
      fallback: fallback,
    );
  }
}

class _BrandLogoImage extends StatefulWidget {
  final String url;
  final double size;
  final int cachePx;
  final Color background;
  final Widget fallback;

  const _BrandLogoImage({
    required this.url,
    required this.size,
    required this.cachePx,
    required this.background,
    required this.fallback,
  });

  @override
  State<_BrandLogoImage> createState() => _BrandLogoImageState();
}

class _BrandLogoImageState extends State<_BrandLogoImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Color? _dominantColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenToImage();
  }

  @override
  void didUpdateWidget(_BrandLogoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.cachePx != widget.cachePx) {
      _listenToImage();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _listenToImage() {
    _removeImageListener();
    _dominantColor = null;
    final provider = ResizeImage(
      NetworkImage(widget.url),
      width: widget.cachePx,
      height: widget.cachePx,
    );
    final stream = provider.resolve(
      createLocalImageConfiguration(
        context,
        size: Size(widget.size, widget.size),
      ),
    );
    final source = widget.url;
    final listener = ImageStreamListener(
      (info, _) => _sampleColor(info.image, source),
      onError: (Object error, StackTrace? stackTrace) {
        if (source == widget.url) _dominantColor = widget.background;
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _stream = null;
    _listener = null;
  }

  Future<void> _sampleColor(ui.Image image, String source) async {
    final color = await _dominant(image);
    if (!mounted || source != widget.url || color == null) return;
    setState(() => _dominantColor = color);
  }

  static Future<Color?> _dominant(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final pixels = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final width = image.width;
    final height = image.height;
    final step = math.max(1, math.max(width, height) ~/ 32);
    final frequencies = <int, int>{};

    for (var y = 0; y < height; y += step) {
      for (var x = 0; x < width; x += step) {
        final index = (y * width + x) * 4;
        if (pixels[index + 3] < 128) continue;
        final key =
            ((pixels[index] >> 3) << 10) |
            ((pixels[index + 1] >> 3) << 5) |
            (pixels[index + 2] >> 3);
        frequencies.update(key, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    if (frequencies.isEmpty) return null;
    var dominantKey = 0;
    var dominantCount = 0;
    for (final entry in frequencies.entries) {
      if (entry.value > dominantCount) {
        dominantKey = entry.key;
        dominantCount = entry.value;
      }
    }
    final red = ((dominantKey >> 10) & 31) * 255 ~/ 31;
    final green = ((dominantKey >> 5) & 31) * 255 ~/ 31;
    final blue = (dominantKey & 31) * 255 ~/ 31;
    return Color.fromARGB(255, red, green, blue);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: ClipOval(
      child: ColoredBox(
        color: _dominantColor ?? widget.background,
        child: Image(
          image: ResizeImage(
            NetworkImage(widget.url),
            width: widget.cachePx,
            height: widget.cachePx,
          ),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, synchronousCall) {
            if (frame == null && !synchronousCall) return widget.fallback;
            return child;
          },
          errorBuilder: (context, error, stackTrace) => widget.fallback,
        ),
      ),
    ),
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
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((p) => p.characters.first.toUpperCase())
              .join();
    final isNetwork =
        path != null &&
        (path!.startsWith('http://') || path!.startsWith('https://'));
    final hasPath = path != null && path!.isNotEmpty;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (size * dpr).round().clamp(48, 384);
    final fallback = Center(
      child: initials.isEmpty
          ? Icon(
              LucideIcons.user,
              color: Palette.brandSky,
              size: size * 0.45,
            )
          : Text(
              initials,
              style: T.bodyStrong.copyWith(
                fontSize: size * 0.36,
                color: Palette.brandSky,
              ),
            ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Palette.brandDeep,
      ),
      child: isNetwork
          ? Image.network(
              path!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              cacheWidth: cachePx,
              cacheHeight: cachePx,
              errorBuilder: (_, _, _) => fallback,
            )
          : hasPath
          ? Image.file(
              File(path!),
              fit: BoxFit.cover,
              width: size,
              height: size,
              cacheWidth: cachePx,
              cacheHeight: cachePx,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
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
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MarkPainter(onDark));
}

class _MarkPainter extends CustomPainter {
  final bool onDark;
  _MarkPainter(this.onDark);
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2;
    final circle = Path()
      ..addOval(Rect.fromCircle(center: Offset(r, r), radius: r));
    canvas.save();
    canvas.clipPath(circle);
    canvas.drawRect(
      Offset.zero & s,
      Paint()
        ..color = onDark
            ? Palette.brandMist.withValues(alpha: 0.85)
            : Palette.brandDeep,
    );
    final y = s.height * 0.52;
    Path wave(double dy) => Path()
      ..moveTo(0, y + dy)
      ..cubicTo(
        s.width * 0.25,
        y - s.height * 0.12 + dy,
        s.width * 0.5,
        y + s.height * 0.12 + dy,
        s.width * 0.75,
        y + dy,
      )
      ..quadraticBezierTo(
        s.width * 0.9,
        y - s.height * 0.08 + dy,
        s.width,
        y - s.height * 0.02 + dy,
      )
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(wave(-s.height * 0.03), Paint()..color = Palette.brandDot);
    canvas.drawPath(
      wave(s.height * 0.02),
      Paint()..color = onDark ? Palette.brandDeep : Palette.brandSky,
    );
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
            style: T.headline.copyWith(
              fontSize: size,
              fontWeight: FontWeight.w700,
              color: color ?? context.c.text,
              letterSpacing: -0.3,
            ),
          ),
          TextSpan(
            text: '.',
            style: T.headline.copyWith(
              fontSize: size,
              fontWeight: FontWeight.w700,
              color: Palette.brandDot,
            ),
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
  const GlowBackground({super.key, this.height = 420, this.tint});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // No escuro usa o tom profundo da cor (primarySoft) em vez do tom 500 vivo: o
    // brilho vira um "ar" da cor, sem competir com o texto branco. O degradê
    // termina exatamente em c.bg, então emenda sem linha com o resto da tela e
    // com o blur progressivo da barra de cima.
    final base = tint ?? (c.isDark ? c.primarySoft : c.primary);
    final warm = c.isDark ? c.secondary : c.accentWarm;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(
                  base.withValues(alpha: c.isDark ? 0.80 : 0.22),
                  c.bg,
                ),
                Color.alphaBlend(
                  base.withValues(alpha: c.isDark ? 0.34 : 0.09),
                  c.bg,
                ),
                c.bg,
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-1.05, -0.9),
                radius: 1.0,
                colors: [
                  warm.withValues(alpha: c.isDark ? 0.28 : 0.12),
                  warm.withValues(alpha: 0),
                ],
              ),
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
      _program = await ui.FragmentProgram.fromAsset(
        'shaders/progressive_blur.frag',
      );
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
    final perf = context.perf;
    final baseColor = widget.tint ?? c.bg;
    final fromTop = widget.direction == AxisDirection.down;
    final begin = fromTop ? Alignment.topCenter : Alignment.bottomCenter;
    final end = fromTop ? Alignment.bottomCenter : Alignment.topCenter;
    final useBlur = perf.allowBlur && widget.maxSigma > 0.15;
    final effectiveTint = useBlur
        ? widget.tintOpacity
        : (widget.tintOpacity * 1.18).clamp(0.0, 0.96);

    final scrim = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            baseColor.withValues(alpha: effectiveTint),
            baseColor.withValues(alpha: effectiveTint * 0.62),
            baseColor.withValues(alpha: effectiveTint * 0.20),
            baseColor.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.36, 0.72, 1.0],
        ),
      ),
    );

    if (!useBlur) {
      // Modo economia de bateria / aparelho low-RAM: zero passes de blur na GPU,
      // mantendo leitura limpa com gradiente suave na cor do fundo.
      return IgnorePointer(child: scrim);
    }

    final shader = _shader;
    if (shader == null || !ui.ImageFilter.isShaderFilterSupported) {
      // Fallback leve (web / Skia sem shader): no máximo 8 faixas para não
      // sobrecarregar GPUs mais antigas.
      const strips = 8;
      return IgnorePointer(
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final h = box.maxHeight;
                  final stripH = h / strips;
                  return Stack(
                    children: [
                      for (var i = 0; i < strips; i++)
                        () {
                          final centre = (i + 0.5) / strips;
                          final t = fromTop ? 1 - centre : centre;
                          final sigma =
                              widget.maxSigma *
                              0.8 *
                              perf.glassSigmaFactor *
                              t *
                              t *
                              t;
                          if (sigma < 0.6) return const SizedBox.shrink();
                          return Positioned(
                            left: 0,
                            right: 0,
                            top: i * stripH,
                            height: stripH + 0.5,
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: sigma,
                                  sigmaY: sigma,
                                  tileMode: TileMode.clamp,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          );
                        }(),
                    ],
                  );
                },
              ),
              scrim,
            ],
          ),
        ),
      );
    }

    // Uniformes após u_size (injetado pelo Impeller nos índices 0 e 1):
    // 2 = u_max_radius, 3 = u_direction, 4 = u_band_px, 5 = u_samples.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final samples = perf.progressiveBlurSamples.toDouble();
    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, box) {
            final bandPx = (box.maxHeight.isFinite ? box.maxHeight : 160.0) * dpr;
            final radiusPx = (widget.maxSigma * dpr * 1.30).clamp(0.0, 68.0);
            shader.setFloat(2, radiusPx);
            shader.setFloat(3, fromTop ? 0.0 : 1.0);
            shader.setFloat(4, bandPx);
            shader.setFloat(5, samples);
            return ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.shader(shader),
                child: scrim,
              ),
            );
          },
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
  const PinnedCupertinoBar({
    super.key,
    this.height = 64,
    this.maxWidth,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedBarDelegate(
        top: top,
        height: height,
        maxWidth: maxWidth,
        builder: builder,
      ),
    );
  }
}

class _PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  final double top;
  final double height;
  final double? maxWidth;
  final Widget Function(BuildContext context, double progress) builder;
  _PinnedBarDelegate({
    required this.top,
    required this.height,
    this.maxWidth,
    required this.builder,
  });

  @override
  double get minExtent => top + height;

  @override
  double get maxExtent => top + height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final c = context.c;
    final pos = Scrollable.maybeOf(context)?.position;
    final fallbackProgress = overlapsContent
        ? 1.0
        : (shrinkOffset / 24).clamp(0.0, 1.0);
    final pad = maxWidth == null
        ? sidePadding(context)
        : sidePadding(context, maxWidth: maxWidth!);

    Widget buildBlur(double t) {
      if (t <= 0.005) return const SizedBox.shrink();
      final eased = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
      return Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: -92,
        child: ProgressiveBlur(
          direction: AxisDirection.down,
          maxSigma: 20 * eased,
          tint: c.isDark ? c.bg : null,
          tintOpacity: (c.isDark ? 0.78 : 0.84) * eased,
        ),
      );
    }

    if (pos != null) {
      return AnimatedBuilder(
        animation: pos,
        builder: (ctx, _) {
          final pixels = pos.hasPixels ? pos.pixels : 0.0;
          final t = (pixels / 36.0).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              buildBlur(t),
              Padding(
                padding: EdgeInsets.fromLTRB(pad, top + Space.sm, pad, Space.sm),
                child: builder(ctx, t),
              ),
            ],
          );
        },
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(end: fallbackProgress),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (ctx, t, _) => Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          buildBlur(t),
          Padding(
            padding: EdgeInsets.fromLTRB(pad, top + Space.sm, pad, Space.sm),
            child: builder(ctx, t),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_PinnedBarDelegate old) => true;
}

/// Coordena o título grande do corpo com o título compacto da `PinnedCupertinoBar`:
/// conforme a tela rola, o título grande desaparece antes de encostar na barra
/// superior e o título da top bar surge no lugar, sem sobreposição.
class CollapsingTitleScope extends StatefulWidget {
  final Widget child;
  const CollapsingTitleScope({super.key, required this.child});

  static ValueListenable<double>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_CollapsingTitleInherited>()
      ?.offset;

  @override
  State<CollapsingTitleScope> createState() => _CollapsingTitleScopeState();
}

class _CollapsingTitleScopeState extends State<CollapsingTitleScope> {
  final _offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CollapsingTitleInherited(
      offset: _offset,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
            final px = n.metrics.pixels;
            if ((px - _offset.value).abs() > 0.25) {
              _offset.value = px;
            }
          }
          return false;
        },
        child: widget.child,
      ),
    );
  }
}

class _CollapsingTitleInherited extends InheritedWidget {
  final ValueListenable<double> offset;
  const _CollapsingTitleInherited({
    required this.offset,
    required super.child,
  });
  @override
  bool updateShouldNotify(_CollapsingTitleInherited old) =>
      old.offset != offset;
}

/// Título compacto na `PinnedCupertinoBar` que só aparece quando o `LargeTitle`
/// já sumiu da tela.
class BarTitle extends StatelessWidget {
  final String text;
  final double? progress;
  const BarTitle(this.text, {super.key, this.progress});

  static const double threshold = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final listenable = CollapsingTitleScope.of(context);
    Widget content(bool visible) => AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      opacity: visible ? 1.0 : 0.0,
      child: Text(
        text,
        style: T.bodyStrong.copyWith(color: c.text),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (listenable == null) {
      return content((progress ?? 0) > 0.35);
    }
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (_, offset, _) => content(offset >= threshold),
    );
  }
}

/// Título grande no topo do corpo que desaparece suavemente ao rolar antes
/// de cruzar com a `PinnedCupertinoBar`.
class LargeTitle extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const LargeTitle(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final resolved = (style ?? T.pageTitle).copyWith(color: c.text);
    final listenable = CollapsingTitleScope.of(context);
    if (listenable == null) {
      return Text(text, style: resolved);
    }
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (_, offset, child) {
        final fade = (1.0 - ((offset - 2.0) / (BarTitle.threshold - 2.0)))
            .clamp(0.0, 1.0);
        return Opacity(opacity: fade, child: child);
      },
      child: Text(text, style: resolved),
    );
  }
}

// ── Estado vazio ────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;
  final Color? bg;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.onAction,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.base),
      decoration: ShapeDecoration(
        color: bg ?? c.card,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Space.radiusCard),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
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
  final r = await _showEdgeSheet<bool>(
    context,
    maxWidth: 520,
    builder: (ctx) {
      final c = ctx.c;
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 4, Space.gutter, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: T.headline.copyWith(
                color: c.text,
                decoration: TextDecoration.none,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                message,
                style: T.label.copyWith(
                  color: c.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    'Cancelar',
                    kind: BtnKind.ghost,
                    background: c.isDark ? c.cardAlt : c.surfaceLow,
                    foreground: c.text,
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
  const SheetAction(
    this.label,
    this.value, {
    this.destructive = false,
    this.icon,
  });
}

/// Modal compacto colado nas bordas laterais e na base (cantos arredondados só em cima).
Future<V?> _showEdgeSheet<V>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 640,
  Color? color,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<V>(
    _EdgeSheetRoute<V>(
      builder: (ctx) {
        final c = ctx.c;
        final mq = MediaQuery.of(ctx);
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: mq.size.height * 0.92,
            ),
            child: ClipRSuperellipse(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: ColoredBox(
                color: color ?? c.card,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: mq.viewInsets.bottom + mq.padding.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragEnd: (d) {
                          if ((d.primaryVelocity ?? 0) > 360) {
                            Navigator.of(ctx).maybePop();
                          }
                        },
                        child: SizedBox(
                          height: 28,
                          width: double.infinity,
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: ShapeDecoration(
                                color: c.borderStrong,
                                shape: RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Flexible(child: builder(ctx)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _EdgeSheetRoute<V> extends PopupRoute<V> {
  final WidgetBuilder builder;
  _EdgeSheetRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Fechar';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: easeOutExpo,
      reverseCurve: Curves.easeInCubic,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: AnimatedBuilder(
              animation: curve,
              builder: (_, _) {
                final t = curve.value.clamp(0.0, 1.0);
                final scrim = ColoredBox(
                  color: const Color(0xFF000000).withValues(alpha: 0.48 * t),
                );
                // Na web ou no modo economia/low-RAM, o véu escuro evita blur
                // em tela cheia e mantém 60fps constantes.
                final perf = context.perfRead;
                if (kIsWeb || !perf.allowBlur) return scrim;
                final sigma = 6.0 * perf.glassSigmaFactor * t;
                if (sigma < 0.3) return scrim;
                return BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                    tileMode: TileMode.clamp,
                  ),
                  child: scrim,
                );
              },
            ),
          ),
        ),
        RepaintBoundary(
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Action sheet compacto colado nas bordas laterais e na base.
Future<V?> actionSheet<V>(
  BuildContext context, {
  String? title,
  String? message,
  required List<SheetAction<V>> actions,
}) {
  return _showEdgeSheet<V>(
    context,
    maxWidth: 520,
    builder: (ctx) {
      final c = ctx.c;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 4, Space.gutter, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || message != null) ...[
              if (title != null)
                Text(
                  title,
                  style: T.headline.copyWith(
                    color: c.text,
                    decoration: TextDecoration.none,
                  ),
                ),
              if (message != null) ...[
                const SizedBox(height: Space.xs),
                Text(
                  message,
                  style: T.label.copyWith(
                    color: c.textSecondary,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
              const SizedBox(height: Space.md),
            ],
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
                decoration: ShapeDecoration(
                  color: c.isDark ? c.cardAlt : c.text,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
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
                style: T.body.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal compacto colado nas bordas laterais e na base para seletores curtos.
Future<V?> showSheet<V>(
  BuildContext context, {
  required Widget Function(BuildContext) builder,
  bool edgeToEdge = true,
  Color? color,
}) {
  return _showEdgeSheet<V>(
    context,
    maxWidth: edgeToEdge ? 640 : 520,
    color: color,
    builder: builder,
  );
}

void toast(
  BuildContext context,
  String message, {
  IconData icon = LucideIcons.check,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final c = context.c;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _Toast(
      message: message,
      icon: icon,
      colors: c,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  final String message;
  final IconData icon;
  final AppColors colors;
  final VoidCallback onDone;
  const _Toast({
    required this.message,
    required this.icon,
    required this.colors,
    required this.onDone,
  });
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

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
          position: Tween(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _a, curve: Curves.easeOutCubic)),
          child: Semantics(
            liveRegion: true,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: ShapeDecoration(
                  color: c.isDark ? c.surfaceHigh : c.text,
                  shadows: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 18,
                      color: ensureContrast(
                        c.accent,
                        [c.isDark ? c.surfaceHigh : c.text],
                        4.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: T.label.copyWith(
                          color: Palette.neutral0,
                          decoration: TextDecoration.none,
                        ),
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
    padding: const EdgeInsets.fromLTRB(
      Space.base,
      Space.lg,
      Space.base,
      Space.sm,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: T.bodyMedium.copyWith(color: context.c.textSecondary),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: Space.sm),
          trailing!,
        ],
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

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.tablet;

// ── Lista agrupada (Figma 460:2951) ─────────────────────────

/// Um cartão único com linhas de 40px, ícone circular, nome à esquerda e valor
/// ou seta à direita. Sem divisórias: o respiro de 20px separa as linhas.
class ListGroup extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final double gap;
  final Color? bg;
  const ListGroup({
    super.key,
    this.title,
    this.trailing,
    required this.children,
    this.gap = 20,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) SectionHeader(title!, trailing: trailing),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: ShapeDecoration(
            color: bg ?? c.card,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Versão lazy (`SliverList.builder`) de [ListGroup] para listas longas
/// (como Extrato e Busca): constrói apenas as linhas visíveis na tela mantendo
/// o mesmo cartão arredondado de 28px e espaçamento entre itens.
class SliverListGroup extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double gap;
  final Color? bg;
  const SliverListGroup({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.gap = 20,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = bg ?? c.card;
    return SliverList.builder(
      itemCount: itemCount,
      itemBuilder: (ctx, i) {
        final isFirst = i == 0;
        final isLast = i == itemCount - 1;
        final radius = BorderRadius.vertical(
          top: isFirst ? const Radius.circular(28) : Radius.zero,
          bottom: isLast ? const Radius.circular(28) : Radius.zero,
        );
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: RoundedSuperellipseBorder(borderRadius: radius),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              isFirst ? 16 : 0,
              16,
              isLast ? 16 : gap,
            ),
            child: itemBuilder(ctx, i),
          ),
        );
      },
    );
  }
}

class ListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Color? titleColor;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool arrow;
  final bool strong;
  const ListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.titleColor,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.arrow = false,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final iconless = leading == null;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 40,
        minWidth: double.infinity,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: (strong
                          ? T.bodyStrong
                          : (iconless ? T.bodyMedium : T.body))
                      .copyWith(color: titleColor ?? c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: T.small.copyWith(color: c.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 10),
            Text(
              value!,
              style: (strong ? T.bodyStrong : T.bodyMedium).copyWith(
                color: valueColor ?? c.text,
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (arrow) ...[
            const SizedBox(width: 10),
            Icon(LucideIcons.arrowUpRight, size: 21, color: c.textSecondary),
          ],
        ],
      ),
    );
    return onTap == null
        ? row
        : Pressable(scale: 0.985, onTap: onTap, child: row);
  }
}

/// Ação rápida: círculo com o ícone dentro e o nome embaixo. A principal vem
/// preenchida (cor de destaque); as demais em cinza neutro; destrutiva em vermelho suave.
class CircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  final double size;
  const CircleAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = danger
        ? c.negativeSoft
        : (primary ? c.primary : c.cardAlt);
    final fg = danger
        ? c.negative
        : (primary ? c.onPrimary : c.text);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      scale: 0.94,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: Icon(icon, size: size * 0.40, color: fg),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: T.small.copyWith(
              color: danger ? c.negative : c.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Sheet estilo iOS: a página de trás recua, encolhe e escurece ─────

/// Progresso (0–1) do sheet aberto; a página de trás reage a ele.
final sheetProgress = ValueNotifier<double>(0);
final List<_IosSheetRoute<dynamic>> _iosSheetStack = [];

void _syncIosSheetProgress() {
  var maxP = 0.0;
  for (final r in _iosSheetStack) {
    final v = (r.animation?.value ?? 0.0) * (1.0 - r._dragFraction);
    if (v > maxP) maxP = v;
  }
  sheetProgress.value = Curves.easeOutCubic.transform(maxP.clamp(0.0, 1.0));
}

/// Envolve a página que fica por trás dos sheets. No iOS a página vira um
/// cartão menor e escuro atrás do sheet; aqui ela encolhe até 93% (ancorada no
/// topo), ganha cantos arredondados e é coberta por um véu preto.
///
/// Otimização (Web/CanvasKit e Mobile):
/// - Mantém a árvore de widgets sempre com a mesma estrutura (nunca desmonta
///   nem remonta [child] quando `p` sai de 0).
/// - Envolve [child] num [RepaintBoundary] fixo para transformar uma textura
///   já rasterizada na GPU.
/// - Usa raio de recorte fixo (20px) ativado apenas quando `p > 0.001`,
///   evitando recompilar o path do clip em todos os frames.
class SheetScaler extends StatelessWidget {
  final Widget child;
  const SheetScaler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cachedChild = RepaintBoundary(child: child);
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: const Color(0xFF000000),
      child: ValueListenableBuilder<double>(
        valueListenable: sheetProgress,
        child: cachedChild,
        builder: (ctx, p, ch) {
          final active = p > 0.001;
          final scale = 1.0 - 0.065 * p;
          final dy = (top * 0.3 + 8) * p;
          final matrix = Matrix4.identity()
            ..setTranslationRaw(0.0, dy, 0.0)
            ..scaleByDouble(scale, scale, 1.0, 1.0);
          return Transform(
            transform: matrix,
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              clipBehavior: active ? Clip.antiAlias : Clip.none,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  ch!,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: active
                          ? ColoredBox(
                              color: const Color(
                                0xFF000000,
                              ).withValues(alpha: 0.52 * p),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Sheet quase em tela cheia (começa logo abaixo da barra de status). Os botões
/// de ação ficam fixos no rodapé quando o conteúdo usa [SheetBody].
Future<R?> showIosSheet<R>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<R>(_IosSheetRoute<R>(builder));
}

class _IosSheetRoute<R> extends PopupRoute<R> {
  _IosSheetRoute(this.builder);
  final WidgetBuilder builder;
  double _dragFraction = 0.0;

  void _setDragFraction(double f) {
    final clamped = f.clamp(0.0, 1.0);
    if (clamped == _dragFraction) return;
    _dragFraction = clamped;
    _syncIosSheetProgress();
  }

  void _completeDismissFromDrag() {
    // Zera o controller antes do pop para não tocar outra transição por cima
    // do sheet que já terminou de descer com o dedo.
    controller?.value = 0.0;
    navigator?.pop();
  }

  @override
  Color? get barrierColor => const Color(0x01000000);
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Fechar';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 440);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  void install() {
    super.install();
    _iosSheetStack.add(this);
    animation!.addListener(_syncIosSheetProgress);
  }

  @override
  void dispose() {
    animation?.removeListener(_syncIosSheetProgress);
    _iosSheetStack.remove(this);
    _syncIosSheetProgress();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top + 14;
    final sheetHeight = math.max(240.0, mq.size.height - top);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _IosSheetFrame(
            height: sheetHeight,
            viewInsetBottom: mq.viewInsets.bottom,
            onDragFraction: _setDragFraction,
            onDismissed: _completeDismissFromDrag,
            child: builder(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: easeOutExpo,
      reverseCurve: Curves.easeInCubic,
    );
    final secCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return RepaintBoundary(
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curve),
        child: AnimatedBuilder(
          animation: secCurve,
          child: child,
          builder: (_, sheetChild) {
            final s = secCurve.value.clamp(0.0, 1.0);
            if (s < 0.001) return sheetChild!;
            final mq = MediaQuery.of(context);
            final top = mq.padding.top + 14;
            final sheetHeight = math.max(240.0, mq.size.height - top);
            final c = context.c;
            final dimAlpha = (c.isDark ? 0.56 : 0.36) * s;
            final scale = 1.0 - 0.055 * s;
            final dy = -12.0 * s;
            final matrix = Matrix4.identity()
              ..setTranslationRaw(0.0, dy, 0.0)
              ..scaleByDouble(scale, scale, 1.0, 1.0);
            return Transform(
              transform: matrix,
              alignment: Alignment.topCenter,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  sheetChild!,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: ClipRSuperellipse(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: sheetHeight,
                              child: ColoredBox(
                                color: const Color(
                                  0xFF000000,
                                ).withValues(alpha: dimAlpha),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IosSheetDragScope extends InheritedWidget {
  final void Function(double deltaY) onDragUpdate;
  final void Function(double velocityY) onDragEnd;
  final bool Function() isDragging;
  const _IosSheetDragScope({
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.isDragging,
    required super.child,
  });

  static _IosSheetDragScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_IosSheetDragScope>();

  @override
  bool updateShouldNotify(_IosSheetDragScope old) => false;
}

class _IosSheetFrame extends StatefulWidget {
  final double height;
  final double viewInsetBottom;
  final ValueChanged<double> onDragFraction;
  final VoidCallback onDismissed;
  final Widget child;
  const _IosSheetFrame({
    required this.height,
    required this.viewInsetBottom,
    required this.onDragFraction,
    required this.onDismissed,
    required this.child,
  });

  @override
  State<_IosSheetFrame> createState() => _IosSheetFrameState();
}

class _IosSheetFrameState extends State<_IosSheetFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  double _offset = 0;
  double _snapFrom = 0;
  double _snapTo = 0;
  bool _dragging = false;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _snap.addListener(() {
      final t = Curves.easeOutCubic.transform(_snap.value);
      final next = _snapFrom + (_snapTo - _snapFrom) * t;
      setState(() => _offset = next);
      widget.onDragFraction(next / widget.height);
    });
  }

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _updateDrag(double dy) {
    if (_dismissing) return;
    if (_snap.isAnimating) _snap.stop();
    _dragging = true;
    final next = (_offset + dy).clamp(0.0, widget.height);
    if (next == _offset) return;
    setState(() => _offset = next);
    widget.onDragFraction(next / widget.height);
  }

  void _endDrag(double velocityY) {
    if (_dismissing || !_dragging) return;
    _dragging = false;
    final shouldClose = _offset > widget.height * 0.24 || velocityY > 520;
    _snapFrom = _offset;
    if (shouldClose) {
      _dismissing = true;
      _snapTo = widget.height;
      final remaining = ((widget.height - _offset) / widget.height).clamp(
        0.15,
        1.0,
      );
      _snap.duration = Duration(milliseconds: (220 * remaining).round());
      _snap.forward(from: 0).then((_) {
        if (mounted) widget.onDismissed();
      });
    } else {
      _snapTo = 0;
      _snap.duration = const Duration(milliseconds: 260);
      _snap.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Transform.translate(
      offset: Offset(0, _offset),
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: ClipRSuperellipse(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ColoredBox(
            color: c.card,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.viewInsetBottom),
              child: _IosSheetDragScope(
                onDragUpdate: _updateDrag,
                onDragEnd: _endDrag,
                isDragging: () => _dragging,
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (d) => _updateDrag(d.delta.dy),
                      onVerticalDragEnd: (d) =>
                          _endDrag(d.primaryVelocity ?? 0),
                      onVerticalDragCancel: () => _endDrag(0),
                      child: SizedBox(
                        height: 28,
                        width: double.infinity,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: ShapeDecoration(
                              color: c.borderStrong,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: widget.child),
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

/// Corpo de sheet: conteúdo rolável + rodapé fixo para os botões de ação.
/// Quando o scroll está no topo (ou não há o que rolar), arrastar para baixo
/// puxa o próprio sheet interativamente para fechar (estilo iOS nativo).
class SheetBody extends StatefulWidget {
  final Widget child;
  final Widget? bottom;
  const SheetBody({super.key, required this.child, this.bottom});

  @override
  State<SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<SheetBody> {
  final _scroll = ScrollController();
  bool _capturing = false;
  double _lastVelocity = 0;
  Duration? _lastMoveTime;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drag = _IosSheetDragScope.of(context);
    return Column(
      children: [
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {
              _capturing = false;
              _lastVelocity = 0;
              _lastMoveTime = null;
            },
            onPointerMove: (e) {
              if (drag == null) return;
              final dy = e.delta.dy;
              final atTop = !_scroll.hasClients || _scroll.offset <= 0.5;
              if (!_capturing) {
                if (atTop && dy > 0 && dy.abs() > e.delta.dx.abs()) {
                  _capturing = true;
                } else {
                  return;
                }
              }
              if (_scroll.hasClients && _scroll.offset != 0) {
                _scroll.jumpTo(0);
              }
              final dtMs = _lastMoveTime == null
                  ? 16
                  : math.max(1, (e.timeStamp - _lastMoveTime!).inMilliseconds);
              _lastVelocity = dy / (dtMs / 1000.0);
              _lastMoveTime = e.timeStamp;
              drag.onDragUpdate(dy);
            },
            onPointerUp: (_) {
              if (_capturing && drag != null) {
                _capturing = false;
                drag.onDragEnd(_lastVelocity);
              }
            },
            onPointerCancel: (_) {
              if (_capturing && drag != null) {
                _capturing = false;
                drag.onDragEnd(0);
              }
            },
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                8,
                Space.gutter,
                24,
              ),
              child: widget.child,
            ),
          ),
        ),
        if (widget.bottom != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                8,
                Space.gutter,
                16,
              ),
              child: widget.bottom,
            ),
          ),
      ],
    );
  }
}

/// Anel circular de progresso reutilizado em Caixinhas e no detalhe de Categoria.
class ProgressRing extends StatelessWidget {
  final double size;
  final double stroke;
  final double fraction;
  final Color color;
  final Color track;
  final Widget child;
  const ProgressRing({
    super.key,
    required this.size,
    required this.stroke,
    required this.fraction,
    required this.color,
    required this.track,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: fraction.clamp(0.0, 1.0),
          color: color,
          track: track,
          stroke: stroke,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;
  final double stroke;
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (fraction > 0) {
      final progPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        progPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
