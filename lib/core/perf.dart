import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Nível adaptativo de qualidade visual e carga de GPU/CPU.
enum PerfTier {
  /// Aparelhos modernos / intermediários fortes: shader completo (32 amostras),
  /// glass com blur completo e animações fluidas.
  high,

  /// Aparelhos intermediários/modestos (<= 5 GB RAM ou Android antigo):
  /// shader leve (14 amostras, >2x mais rápido na GPU) e blur moderado.
  balanced,

  /// Economia de bateria ativa, aparelho low-RAM (<= 3 GB) ou "reduzir movimento":
  /// zero passes de blur na GPU (substituídos por gradientes e superfícies limpas),
  /// cache de imagens enxuto e animações simplificadas.
  economy,
}

/// Diagnóstico adaptativo de hardware e economia de bateria.
/// Reage ao vivo quando o usuário liga/desliga a Economia de Bateria no Android.
class DevicePerf extends ChangeNotifier {
  DevicePerf._();
  static final DevicePerf instance = DevicePerf._();

  static const _deviceCh = MethodChannel('com.mare.mare/device');
  static const _powerCh = EventChannel('com.mare.mare/power_save');

  bool _initialized = false;
  bool _powerSave = false;
  bool _lowRam = false;
  int _totalRamMb = 0;
  int _cpuCores = 8;
  int _sdkInt = 34;
  StreamSubscription<dynamic>? _powerSub;

  bool get isPowerSaveMode => _powerSave;
  bool get isLowRamDevice => _lowRam;
  int get totalRamMb => _totalRamMb;

  PerfTier get tier {
    if (_powerSave || _lowRam || (_totalRamMb > 0 && _totalRamMb <= 3200)) {
      return PerfTier.economy;
    }
    if ((_totalRamMb > 0 && _totalRamMb <= 5500) ||
        (_sdkInt > 0 && _sdkInt < 30) ||
        _cpuCores <= 4) {
      return PerfTier.balanced;
    }
    return PerfTier.high;
  }

  /// Se efeitos de blur na GPU (BackdropFilter e shader progressivo) devem rodar.
  bool get allowBlur => tier != PerfTier.economy;

  /// Quantidade de amostras do shader de blur progressivo (32 no high, 14 no balanced).
  int get progressiveBlurSamples => switch (tier) {
    PerfTier.high => 32,
    PerfTier.balanced => 14,
    PerfTier.economy => 0,
  };

  /// Fator multiplicador para sigma de `BackdropFilter` em elementos glass.
  double get glassSigmaFactor => switch (tier) {
    PerfTier.high => 1.0,
    PerfTier.balanced => 0.55,
    PerfTier.economy => 0.0,
  };

  /// Se animações decorativas (splash, contadores com mola, reveals) devem ser
  /// encurtadas/puladas para poupar CPU e bateria.
  bool get simplifyMotion => tier == PerfTier.economy;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await refresh();
    try {
      _powerSub = _powerCh.receiveBroadcastStream().listen(
        (event) {
          if (event is bool && event != _powerSave) {
            _powerSave = event;
            _applyMemoryLimits();
            notifyListeners();
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      // Ambientes de teste sem canal nativo ignoram silenciosamente.
    }
  }

  /// Reconsulta o estado atual do aparelho (útil ao voltar do segundo plano).
  Future<void> refresh() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final raw = await _deviceCh.invokeMapMethod<String, dynamic>(
        'getCapabilities',
      );
      if (raw == null) return;
      final prevTier = tier;
      _powerSave = raw['isPowerSaveMode'] == true;
      _lowRam = raw['isLowRamDevice'] == true;
      _totalRamMb = (raw['totalRamMb'] as num?)?.toInt() ?? _totalRamMb;
      _cpuCores = (raw['cpuCores'] as num?)?.toInt() ?? _cpuCores;
      _sdkInt = (raw['sdkInt'] as num?)?.toInt() ?? _sdkInt;
      _applyMemoryLimits();
      if (tier != prevTier) notifyListeners();
    } catch (_) {
      // Testes unitários/widget ou plataformas sem o canal mantêm defaults.
    }
  }

  void _applyMemoryLimits() {
    try {
      final cache = PaintingBinding.instance.imageCache;
      switch (tier) {
        case PerfTier.economy:
          cache.maximumSizeBytes = 28 << 20; // 28 MB
          cache.maximumSize = 120;
        case PerfTier.balanced:
          cache.maximumSizeBytes = 48 << 20; // 48 MB
          cache.maximumSize = 250;
        case PerfTier.high:
          cache.maximumSizeBytes = 96 << 20; // 96 MB
          cache.maximumSize = 500;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _powerSub?.cancel();
    super.dispose();
  }
}

/// Escopo reativo para que widgets consultem o tier atual (`context.perf`)
/// e se adaptem automaticamente quando a economia de bateria muda.
class PerfScope extends InheritedNotifier<DevicePerf> {
  const PerfScope({
    super.key,
    required DevicePerf perf,
    required super.child,
  }) : super(notifier: perf);

  static DevicePerf of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PerfScope>()?.notifier ??
      DevicePerf.instance;

  static DevicePerf read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PerfScope>()?.notifier ??
      DevicePerf.instance;
}

extension PerfContext on BuildContext {
  DevicePerf get perf => PerfScope.of(this);
  DevicePerf get perfRead => PerfScope.read(this);
}
