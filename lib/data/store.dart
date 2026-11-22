import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/cycle.dart';
import '../core/money.dart';
import 'finance.dart';
import 'models.dart';
import 'validation.dart';

/// Estado do app + persistência local. Toda alteração passa por aqui, salva
/// e notifica a UI.
class Store extends ChangeNotifier {
  static const _key = 'mare_v1';
  final SharedPreferences _prefs;
  AppData data;
  VoidCallback? onLocalChange;

  Store._(this._prefs, this.data);

  SharedPreferences get prefs => _prefs;

  static Future<Store> load() async {
    final prefs = await SharedPreferences.getInstance();
    AppData d;
    try {
      final raw = prefs.getString(_key);
      d = raw == null
          ? AppData()
          : AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Nunca travar o app por causa de dado corrompido: guarda uma cópia e recomeça.
      final raw = prefs.getString(_key);
      if (raw != null) {
        await prefs.setString(
          '${_key}_corrupt_${DateTime.now().millisecondsSinceEpoch}',
          raw,
        );
      }
      d = AppData();
    }
    final migrated = sanitizeAppData(d);
    if (migrated) {
      await prefs.setString(_key, jsonEncode(d.toJson()));
    }
    return Store._(prefs, d);
  }

  /// Cria um Finance "agora" — barato, sem cache para nunca ficar defasado.
  Finance get f => Finance(data);
  Cycle get cycle => f.current;
  int _keyOf(DateTime d) => Cycle.of(d, data.cycleStartDay).key;

  void _commit({bool isRemote = false}) {
    if (!isRemote) {
      data.updatedAt = DateTime.now().toUtc();
    }
    _prefs.setString(_key, jsonEncode(data.toJson()));
    notifyListeners();
    if (!isRemote) onLocalChange?.call();
  }

  /// Indica se já existem dados financeiros/configuração relevantes neste aparelho.
  bool get hasMeaningfulData =>
      data.onboardingDone ||
      data.expenses.isNotEmpty ||
      data.boxes.isNotEmpty ||
      data.salaries.isNotEmpty ||
      data.cards.isNotEmpty;

  // ── Perfil / preferências ─────────────────────────────────

  void setProfile({
    String? name,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    if (name != null) data.userName = name.trim();
    if (clearAvatar) data.avatarPath = null;
    if (avatarPath != null) data.avatarPath = avatarPath;
    _commit();
  }

  void setTheme(ThemePref t) {
    data.theme = t;
    _commit();
  }

  void setAccentColor(int color) {
    data.accentColor = color;
    _commit();
  }

  void toggleHideValues() {
    data.hideValues = !data.hideValues;
    _commit();
  }

  void setCardSpan(String id, int span) {
    data.cardSpans[id] = span.clamp(1, 2);
    _commit();
  }

  void setDashboardLayout({List<String>? order, List<String>? hidden}) {
    if (order != null) data.widgetOrder = List<String>.from(order);
    if (hidden != null) data.hiddenWidgets = List<String>.from(hidden);
    _commit();
  }

  void resetDashboardLayout() {
    data.widgetOrder = [];
    data.hiddenWidgets = [];
    data.cardSpans = {};
    _commit();
  }

  void setCycleStartDay(int day) {
    data.cycleStartDay = day.clamp(1, 31);
    _commit();
  }

  /// O salário vale a partir do ciclo atual; ciclos anteriores mantêm o valor antigo.
  String? setSalary(Cents cents) {
    final err = validateSalary(cents);
    if (err != null) return err;
    final k = cycle.key;
    data.salaries
      ..removeWhere((s) => s.fromKey >= k)
      ..add(SalaryEntry(k, cents))
      ..sort((a, b) => a.fromKey.compareTo(b.fromKey));
    _commit();
    return null;
  }

  void finishOnboarding({
    required String name,
    required Cents salary,
    required int startDay,
    String? avatarPath,
  }) {
    data
      ..userName = name.trim()
      ..avatarPath = avatarPath ?? data.avatarPath
      ..cycleStartDay = startDay.clamp(1, 31)
      ..onboardingDone = true;
    final cleanSalary = salary.clamp(0, MoneyLimits.maxCents);
    if (cleanSalary > 0) {
      data.salaries = [SalaryEntry(cycle.key, cleanSalary)];
    }
    _commit();
  }

  // ── Gastos ────────────────────────────────────────────────

  String? addExpense(Expense e) {
    final validCards = data.cards.map((c) => c.id).toSet();
    final err = validateExpense(e, validCardIds: validCards);
    if (err != null) return err;
    normalizeExpense(e, validCardIds: validCards);
    data.expenses.add(e);
    _commit();
    return null;
  }

  /// Edita um gasto. Se for recorrente, já tiver vigorado em ciclos anteriores
  /// e o valor mudou, o histórico é preservado: o antigo encerra no ciclo
  /// anterior e o novo passa a valer a partir de agora.
  String? updateExpense(Expense edited) {
    final i = data.expenses.indexWhere((e) => e.id == edited.id);
    if (i < 0) return 'Gasto não encontrado.';
    final validCards = data.cards.map((c) => c.id).toSet();
    final err = validateExpense(edited, validCardIds: validCards);
    if (err != null) return err;
    normalizeExpense(edited, validCardIds: validCards);
    final old = data.expenses[i];
    final cur = cycle;
    final startedBefore = Cycle.of(old.date, data.cycleStartDay).key < cur.key;
    if (old.isRecurring &&
        edited.isRecurring &&
        startedBefore &&
        old.cents != edited.cents) {
      old.endDate = cur.start.subtract(const Duration(days: 1));
      data.expenses.add(
        Expense(
          name: edited.name,
          cents: edited.cents,
          categoryId: edited.categoryId,
          cardId: edited.cardId,
          date: cur.start,
          recurrence: Recurrence.monthly,
          endDate: edited.endDate,
        ),
      );
    } else {
      data.expenses[i] = edited;
    }
    _commit();
    return null;
  }

  /// Para de cobrar um recorrente: continua valendo neste ciclo e some do próximo.
  void endRecurring(String id) {
    final e = data.expenses.where((e) => e.id == id).firstOrNull;
    if (e == null) return;
    e.endDate = cycle.end.subtract(const Duration(days: 1));
    _commit();
  }

  void deleteExpense(String id) {
    data.expenses.removeWhere((e) => e.id == id);
    _commit();
  }

  /// Nomes já usados, mais recentes primeiro, com a última categoria escolhida.
  List<MapEntry<String, String>> recentNames({int limit = 8}) {
    final seen = <String>{};
    final out = <MapEntry<String, String>>[];
    final sorted = [...data.expenses]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final e in sorted) {
      final k = e.name.trim().toLowerCase();
      if (k.isEmpty || !seen.add(k)) continue;
      out.add(MapEntry(e.name.trim(), e.categoryId));
      if (out.length >= limit) break;
    }
    return out;
  }

  // ── Caixinhas ─────────────────────────────────────────────

  Caixinha? box(String id) => data.boxes.where((b) => b.id == id).firstOrNull;

  String? addBox({
    required String name,
    required String icon,
    required int color,
    required PlanMode mode,
    required int amount,
    Cents? goal,
  }) {
    final err = validateBoxParams(
      name: name,
      mode: mode,
      amount: amount,
      goal: goal,
    );
    if (err != null) return err;
    final k = cycle.key;
    final cleanGoal = (goal != null && goal > 0) ? goal : null;
    data.boxes.add(
      Caixinha(
        name: name.trim(),
        icon: boxIcons.containsKey(icon) ? icon : 'piggy',
        color: color,
        goalCents: cleanGoal,
        createdKey: k,
        plans: [ContributionPlan(k, mode, amount)],
      ),
    );
    _commit();
    return null;
  }

  /// Mudar o aporte só afeta deste ciclo em diante.
  String? updateBox(
    String id, {
    required String name,
    required String icon,
    required int color,
    required PlanMode mode,
    required int amount,
    Cents? goal,
  }) {
    final b = box(id);
    if (b == null) return 'Caixinha não encontrada.';
    final err = validateBoxParams(
      name: name,
      mode: mode,
      amount: amount,
      goal: goal,
    );
    if (err != null) return err;
    final k = cycle.key;
    final cur = b.currentPlan;
    if (cur.mode != mode || cur.amount != amount) {
      final sim = Caixinha.fromJson(b.toJson());
      sim.plans
        ..removeWhere((p) => p.fromKey >= k)
        ..add(ContributionPlan(k, mode, amount));
      if (f.boxRawBalance(sim) < 0) {
        return 'Esse aporte deixaria o saldo da caixinha negativo.';
      }
      b.plans
        ..removeWhere((p) => p.fromKey >= k)
        ..add(ContributionPlan(k, mode, amount));
    }
    b
      ..name = name.trim()
      ..icon = boxIcons.containsKey(icon) ? icon : 'piggy'
      ..color = color
      ..goalCents = (goal != null && goal > 0) ? goal : null;
    _commit();
    return null;
  }

  /// Apaga a caixinha e todo o histórico dela (como se nunca tivesse existido).
  void deleteBox(String id) {
    data.boxes.removeWhere((b) => b.id == id);
    _commit();
  }

  /// Encerra a caixinha devolvendo o saldo ao ciclo atual. O histórico fica.
  void closeBox(String id) {
    final b = box(id);
    if (b == null) return;
    final bal = f.boxBalance(b);
    if (bal > 0) {
      b.movements.add(
        Movement(
          name: 'Resgate ao encerrar',
          cents: bal,
          type: MovementType.redeem,
          date: DateTime.now(),
        ),
      );
    }
    b.closedKey = cycle.key;
    _commit();
  }

  String? addMovement(String boxId, Movement m) {
    final b = box(boxId);
    final err = validateMovement(f, b, m);
    if (err != null) return err;
    normalizeMovement(m);
    b!.movements.add(m);
    _commit();
    return null;
  }

  String? updateMovement(String boxId, Movement m) {
    final b = box(boxId);
    if (b == null) return 'Caixinha não encontrada.';
    final i = b.movements.indexWhere((x) => x.id == m.id);
    if (i < 0) return 'Movimentação não encontrada.';
    final err = validateMovement(f, b, m, replacingId: m.id);
    if (err != null) return err;
    normalizeMovement(m);
    b.movements[i] = m;
    _commit();
    return null;
  }

  String? deleteMovement(String boxId, String movementId) {
    final b = box(boxId);
    if (b == null) return 'Caixinha não encontrada.';
    final existing = b.movements.where((m) => m.id == movementId).firstOrNull;
    if (existing == null) return null;
    if (existing.sign > 0 && b.isOpen) {
      final sim = Caixinha.fromJson(b.toJson());
      sim.movements.removeWhere((m) => m.id == movementId);
      if (f.boxRawBalance(sim) < 0) {
        return 'Não é possível excluir este depósito porque parte do saldo já foi usada ou resgatada.';
      }
    }
    b.movements.removeWhere((m) => m.id == movementId);
    _commit();
    return null;
  }

  void endMovement(String boxId, String movementId) {
    final m = box(
      boxId,
    )?.movements.where((m) => m.id == movementId).firstOrNull;
    if (m == null) return;
    m.endDate = cycle.end.subtract(const Duration(days: 1));
    _commit();
  }

  // ── Cartões ───────────────────────────────────────────────

  PayCard? card(String? id) =>
      id == null ? null : data.cards.where((c) => c.id == id).firstOrNull;

  String? saveCard(PayCard c) {
    final err = validateCard(c);
    if (err != null) return err;
    normalizeCard(c);
    final i = data.cards.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      data.cards[i] = c;
    } else {
      data.cards.add(c);
    }
    _commit();
    return null;
  }

  void deleteCard(String id) {
    data.cards.removeWhere((c) => c.id == id);
    for (final e in data.expenses) {
      if (e.cardId == id) e.cardId = null;
    }
    _commit();
  }

  // ── Backup ────────────────────────────────────────────────

  String exportJson() =>
      const JsonEncoder.withIndent('  ').convert(data.toJson());

  /// Aceita backup do maré ou do app web antigo (finapp). Retorna mensagem de erro ou null.
  String? importJson(
    String raw, {
    bool fromCloud = false,
    DateTime? cloudUpdatedAt,
  }) {
    try {
      final j = jsonDecode(raw.trim());
      if (j is! Map) return 'O conteúdo não é um backup válido.';
      final map = Map<String, dynamic>.from(j);
      if (map.containsKey('mareVersion')) {
        data = AppData.fromJson(map);
      } else if (map.containsKey('finappBackupVersion') ||
          map.containsKey('expenses') ||
          map.containsKey('caixinhas')) {
        data = AppData.fromLegacy(map, keyOf: _keyOf);
      } else {
        return 'Não reconheci esse formato de backup.';
      }
      data.onboardingDone = true;
      sanitizeAppData(data);
      if (fromCloud) {
        data.updatedAt =
            (data.updatedAt ?? cloudUpdatedAt ?? DateTime.now()).toUtc();
      }
      _commit(isRemote: fromCloud);
      return null;
    } catch (_) {
      return 'Não consegui ler esse texto. Confira se copiou o backup inteiro.';
    }
  }

  void resetAll() {
    data = AppData();
    _commit();
  }
}

class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child})
    : super(notifier: store);

  static Store of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static Store read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

extension StoreX on BuildContext {
  Store get store => StoreScope.of(this);
  Store get storeRead => StoreScope.read(this);
}
