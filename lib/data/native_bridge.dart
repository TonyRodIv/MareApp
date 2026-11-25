import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import '../core/money.dart';
import 'brands.dart';
import 'models.dart';
import 'store.dart';

bool get isAndroidNative =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Sincroniza os valores atuais do ciclo com os widgets nativos da tela inicial.
class NativeWidgets {
  static const _ch = MethodChannel('com.mare.mare/widgets');

  static Future<void> syncFromStore(Store s) async {
    if (!isAndroidNative) return;
    final f = s.f;
    final cy = f.current;
    final hidden = s.data.hideValues;
    final daysLeft = f.daysLeftInclToday;
    final openBoxes = f.openBoxes;
    final subs = f.subscriptions(cy);
    final subsTotal = subs.fold<int>(0, (t, e) => t + e.cents);
    final cats = f.byCategory(cy);
    final catTotal = cats.fold<int>(0, (t, e) => t + e.value);

    final spark = <double>[
      for (final cItem in f.lastCycles(6)) f.expensesTotal(cItem).toDouble(),
    ];
    final prevSpent = f.expensesTotal(cy.prev(s.data.cycleStartDay));
    final spent = f.expensesTotal(cy);
    final isHigh = prevSpent > 0 ? spent > prevSpent : false;

    final boxColors = <int>[];
    final boxValues = <int>[];
    for (final b in openBoxes) {
      final bal = f.boxBalance(b);
      if (bal > 0) {
        boxColors.add(b.color);
        boxValues.add(bal);
      }
    }

    final subColors = <int>[
      for (var i = 0; i < subs.length && i < 4; i++)
        (brandSpecFor(subs[i].name)?.bg ??
                brandSpecFor(subs[i].name)?.accent ??
                subs[i].category.color)
            .toARGB32(),
    ];
    final subLabels = <String>[
      for (var i = 0; i < subs.length && i < 4; i++)
        subs[i].name.trim().isEmpty
            ? '?'
            : subs[i].name.trim()[0].toUpperCase(),
    ];
    final subDomains = <String>[
      for (var i = 0; i < subs.length && i < 4; i++)
        brandSpecFor(subs[i].name)?.domain ?? '',
    ];
    final subInsets = <String>[
      for (var i = 0; i < subs.length && i < 4; i++)
        (brandSpecFor(subs[i].name)?.inset ?? 0.08).toStringAsFixed(2),
    ];
    final subExtra = subs.length > 4 ? subs.length - 4 : 0;

    final catColors = <int>[
      for (var i = 0; i < cats.length && i < 4; i++)
        cats[i].key.color.toARGB32(),
    ];
    final catValues = <int>[
      for (var i = 0; i < cats.length && i < 4; i++) cats[i].value,
    ];

    String catLine(int idx) {
      if (idx >= cats.length || catTotal <= 0) return '';
      final item = cats[idx];
      final pct = (item.value / catTotal * 100).round();
      final val = fmtMoney(item.value, hidden: hidden);
      return '${item.key.label} · $pct% · $val';
    }
    final openSplits = [
      for (final b in s.data.splitBills)
        if (!b.isFullySettled) b,
    ];
    final splitTotal = openSplits.fold<int>(0, (t, b) => t + b.totalCents);
    final splitCaption = openSplits.isEmpty
        ? 'Tudo quitado'
        : '${openSplits.length} ${openSplits.length == 1 ? 'conta em aberto' : 'contas em aberto'}';

    try {
      await _ch.invokeMethod<bool>('updateSnapshot', {
        'freeBalance': fmtMoney(f.freeBalance(cy), hidden: hidden),
        'expensesTotal': fmtMoney(spent, hidden: hidden),
        'boxesTotal': fmtMoney(f.boxesBalanceTotal(), hidden: hidden),
        'boxesCaption': openBoxes.isEmpty
            ? 'Sem caixinhas ativas'
            : '${openBoxes.length} ${openBoxes.length == 1 ? 'caixinha' : 'caixinhas'}',
        'subsTotal': fmtMoney(subsTotal, hidden: hidden),
        'subsCaption': subs.isEmpty
            ? 'Nenhuma assinatura'
            : '${subs.length} ${subs.length == 1 ? 'serviço' : 'serviços'} · por mês',
        'cat1': cats.isEmpty ? 'Sem gastos neste ciclo' : catLine(0),
        'cat2': catLine(1),
        'cat3': catLine(2),
        'cat4': catLine(3),
        'cycleLabel': cy.label(),
        'caption': daysLeft == 1
            ? 'Último dia do ciclo'
            : 'Faltam $daysLeft dias no ciclo',
        'sparkCsv': spark.join(','),
        'sparkColor': isHigh ? 0xFFFF3B30 : 0xFF34C759,
        'boxColorsCsv': boxColors.join(','),
        'boxValuesCsv': boxValues.join(','),
        'subColorsCsv': subColors.join(','),
        'subLabelsCsv': subLabels.join(','),
        'subDomainsCsv': subDomains.join(','),
        'subInsetsCsv': subInsets.join(','),
        'subExtra': subExtra,
        'catColorsCsv': catColors.join(','),
        'catValuesCsv': catValues.join(','),
        'splitTotal': fmtMoney(splitTotal, hidden: hidden),
        'splitCaption': splitCaption,
      });
    } catch (_) {}
  }

  static Future<bool> canPin() async {
    if (!isAndroidNative) return false;
    try {
      return await _ch.invokeMethod<bool>('canPin') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> pinWidget(String kind) async {
    if (!isAndroidNative) return false;
    try {
      return await _ch.invokeMethod<bool>('pinWidget', {'kind': kind}) ?? false;
    } catch (_) {
      return false;
    }
  }
}

class BankSuggestion {
  final String id;
  final String name;
  final Cents cents;
  final String bankName;
  final DateTime timestamp;

  const BankSuggestion({
    required this.id,
    required this.name,
    required this.cents,
    required this.bankName,
    required this.timestamp,
  });

  factory BankSuggestion.fromMap(Map<Object?, Object?> m) => BankSuggestion(
    id: '${m['id'] ?? ''}',
    name: '${m['name'] ?? ''}',
    cents: (m['cents'] as num?)?.toInt() ?? 0,
    bankName: '${m['bankName'] ?? ''}',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (m['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    ),
  );
}

/// Serviço que lê sugestões geradas por notificações de bancos no Android.
class BankNotifications {
  static const _ch = MethodChannel('com.mare.mare/bank_notifications');
  static const _events = EventChannel('com.mare.mare/bank_events');

  static Stream<String> get events {
    if (!isAndroidNative) return const Stream.empty();
    return _events
        .receiveBroadcastStream()
        .map((e) => '$e')
        .handleError((_) {});
  }

  static Future<bool> isEnabled() async {
    if (!isAndroidNative) return false;
    try {
      return await _ch.invokeMethod<bool>('isEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!isAndroidNative) return;
    try {
      await _ch.invokeMethod<bool>('setEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  static Future<bool> hasAccess() async {
    if (!isAndroidNative) return false;
    try {
      return await _ch.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPostPermission() async {
    if (!isAndroidNative) return false;
    try {
      return await _ch.invokeMethod<bool>('hasPostPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestPostPermission() async {
    if (!isAndroidNative) return;
    try {
      await _ch.invokeMethod<bool>('requestPostPermission');
    } catch (_) {}
  }

  static Future<void> openAccessSettings() async {
    if (!isAndroidNative) return;
    try {
      await _ch.invokeMethod<bool>('openAccessSettings');
    } catch (_) {}
  }

  static Future<void> openAppInfoSettings() async {
    if (!isAndroidNative) return;
    try {
      await _ch.invokeMethod<bool>('openAppInfoSettings');
    } catch (_) {}
  }

  static Future<List<BankSuggestion>> getPending() async {
    if (!isAndroidNative) return const [];
    try {
      final raw = await _ch.invokeMethod<List<Object?>>('getPending');
      if (raw == null) return const [];
      return [
        for (final item in raw)
          if (item is Map) BankSuggestion.fromMap(item),
      ].where((e) => e.id.isNotEmpty && e.cents > 0).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> dismissPending(String id) async {
    if (!isAndroidNative) return;
    try {
      await _ch.invokeMethod<bool>('dismissPending', {'id': id});
    } catch (_) {}
  }

  static Future<List<BankSuggestion>> consumeApproved() async {
    if (!isAndroidNative) return const [];
    try {
      final raw = await _ch.invokeMethod<List<Object?>>('consumeApproved');
      if (raw == null) return const [];
      return [
        for (final item in raw)
          if (item is Map) BankSuggestion.fromMap(item),
      ].where((e) => e.id.isNotEmpty && e.cents > 0).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> consumeLaunchAction() async {
    if (!isAndroidNative) return null;
    try {
      return await _ch.invokeMethod<String>('consumeLaunchAction');
    } catch (_) {
      return null;
    }
  }

  /// Converte uma sugestão em [Expense], casando categoria e conta/cartão.
  static String? saveSuggestion(Store s, BankSuggestion item) {
    final remembered = s
        .recentNames(limit: 50)
        .where((e) => foldText(e.key) == foldText(item.name))
        .firstOrNull;
    final catId = remembered?.value ?? guessCategory(item.name)?.id ?? 'outros';
    final bankKey = foldText(item.bankName);
    final matchedCard = s.data.cards
        .where((k) => foldText(k.name).contains(bankKey) || bankKey.contains(foldText(k.name)))
        .firstOrNull;
    return s.addExpense(
      Expense(
        name: item.name,
        cents: item.cents,
        categoryId: catId,
        cardId: matchedCard?.id,
        date: item.timestamp,
      ),
    );
  }
}
