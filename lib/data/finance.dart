import 'dart:math';

import '../core/cycle.dart';
import '../core/money.dart';
import 'models.dart';

/// Toda a matemática do app, sem estado de UI. Tudo é calculado a partir de
/// lançamentos datados — não há "snapshots" que dependem de o app ter sido
/// aberto no mês (problema do histórico no original).
class Finance {
  final AppData d;
  final DateTime now;
  Finance(this.d, {DateTime? now}) : now = now ?? DateTime.now();

  int get startDay => d.cycleStartDay;
  Cycle cycleOf(DateTime date) => Cycle.of(date, startDay);
  Cycle get current => cycleOf(now);
  Cycle fromKey(int k) => Cycle.fromKey(k, startDay);

  // ── Vigência ──────────────────────────────────────────────

  bool _activeIn({
    required DateTime date,
    required Recurrence rec,
    DateTime? end,
    required Cycle c,
  }) {
    final startKey = cycleOf(date).key;
    if (rec == Recurrence.once) return startKey == c.key;
    if (c.key < startKey) return false;
    if (end == null) return true;
    return c.key <= cycleOf(end).key;
  }

  bool expenseActive(Expense e, Cycle c) =>
      _activeIn(date: e.date, rec: e.recurrence, end: e.endDate, c: c);
  bool movementActive(Movement m, Cycle c) =>
      _activeIn(date: m.date, rec: m.recurrence, end: m.endDate, c: c);

  // ── Salário ───────────────────────────────────────────────

  Cents salaryFor(Cycle c) {
    SalaryEntry? found;
    for (final s in d.salaries) {
      if (s.fromKey <= c.key && (found == null || s.fromKey >= found.fromKey)) {
        found = s;
      }
    }
    return max(0, found?.cents ?? 0);
  }

  Cents get salary => salaryFor(current);

  // ── Gastos ────────────────────────────────────────────────

  List<Expense> expensesIn(Cycle c) =>
      d.expenses.where((e) => expenseActive(e, c)).toList();

  Cents expensesTotal(Cycle c) => expensesIn(c).fold(0, (s, e) => s + e.cents);
  Cents fixedTotal(Cycle c) =>
      expensesIn(c).where((e) => e.isRecurring).fold(0, (s, e) => s + e.cents);
  Cents variableTotal(Cycle c) =>
      expensesIn(c).where((e) => !e.isRecurring).fold(0, (s, e) => s + e.cents);

  /// Gastos únicos lançados num dia específico.
  Cents spentOn(DateTime day) => d.expenses
      .where((e) => !e.isRecurring && sameDay(e.date, day))
      .fold(0, (s, e) => s + e.cents);

  // ── Caixinhas ─────────────────────────────────────────────

  Cents contributionFor(Caixinha b, Cycle c) {
    if (c.key < b.createdKey) return 0;
    if (b.closedKey != null && c.key > b.closedKey!) return 0;
    final p = b.planFor(c.key);
    if (p == null || p.amount <= 0) return 0;
    if (p.mode == PlanMode.fixed) return max(0, p.amount);
    return max(0, (salaryFor(c) * p.amount / 10000).round());
  }

  Cents contributionsTotal(Cycle c) =>
      d.boxes.fold(0, (s, b) => s + contributionFor(b, c));

  Cents _movementsIn(Caixinha b, Cycle c, MovementType t) => b.movements
      .where((m) => m.type == t && movementActive(m, c))
      .fold(0, (s, m) => s + max(0, m.cents));

  /// Saldo bruto acumulado da caixinha até o fim do ciclo [upTo] (inclusivo),
  /// sem clamp em zero — usado pelo validador para detectar déficit real.
  Cents boxRawBalance(Caixinha b, {Cycle? upTo}) {
    final last = (upTo ?? current).key;
    var total = 0;
    final firstMove = b.movements.isEmpty
        ? b.createdKey
        : b.movements.map((m) => cycleOf(m.date).key).reduce(min);
    for (var k = min(b.createdKey, firstMove); k <= last; k++) {
      final c = fromKey(k);
      total += contributionFor(b, c);
      for (final m in b.movements) {
        if (movementActive(m, c)) total += m.sign * max(0, m.cents);
      }
    }
    return total;
  }

  /// Saldo acumulado da caixinha até o fim do ciclo [upTo] (inclusivo).
  /// Nunca fica negativo (garantido pela validação e protegido contra dados legados).
  Cents boxBalance(Caixinha b, {Cycle? upTo}) =>
      max(0, boxRawBalance(b, upTo: upTo));

  List<Caixinha> get openBoxes => d.boxes.where((b) => b.isOpen).toList();
  Cents boxesBalanceTotal() => openBoxes.fold(0, (s, b) => s + boxBalance(b));

  /// Ciclos até atingir a meta, mantendo o aporte atual. null = sem meta/aporte.
  int? cyclesToGoal(Caixinha b) {
    final goal = b.goalCents;
    if (goal == null || goal <= 0) return null;
    final bal = boxBalance(b);
    if (bal >= goal) return 0;
    final per = contributionFor(b, current.next(startDay));
    if (per <= 0) return null;
    return ((goal - bal) / per).ceil();
  }

  // ── Saldo livre ───────────────────────────────────────────

  /// O que sobra do salário no ciclo depois de gastos, aportes e depósitos
  /// extras; resgates voltam para cá.
  Cents freeBalance(Cycle c) {
    var v = salaryFor(c) - expensesTotal(c) - contributionsTotal(c);
    for (final b in d.boxes) {
      v -= _movementsIn(b, c, MovementType.deposit);
      v += _movementsIn(b, c, MovementType.redeem);
    }
    return v;
  }

  /// Compromissos fixos do ciclo (tudo que não é gasto do dia a dia).
  Cents committed(Cycle c) => salaryFor(c) - variableTotal(c) - freeBalance(c);

  /// Orçamento para o dia a dia no ciclo inteiro.
  Cents variableBudget(Cycle c) => salaryFor(c) - committed(c);

  /// Meta diária "ideal" do ciclo, usada para pintar o calendário e a sequência.
  Cents idealDaily(Cycle c) =>
      max(0, variableBudget(c)) ~/ max(1, c.lengthInDays);

  // ── Ritmo do dia ──────────────────────────────────────────

  int get daysLeftInclToday =>
      current.end.difference(dateOnly(now)).inDays.clamp(1, 31);

  /// Quanto ainda dá para gastar hoje mantendo o ritmo até o fim do ciclo.
  Cents get todayAllowance {
    final today = dateOnly(now);
    final spentToday = spentOn(today);
    final startOfDay = freeBalance(current) + spentToday;
    final perDay = max(0, startOfDay) ~/ daysLeftInclToday;
    return perDay - spentToday;
  }

  /// Dias de fim de semana à frente (incluindo hoje) dentro do ciclo atual.
  List<DateTime> get upcomingWeekend {
    final today = dateOnly(now);
    final out = <DateTime>[];
    var d = today;
    while (d.isBefore(current.end) && out.length < 2) {
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        out.add(d);
      } else if (out.isNotEmpty) {
        break;
      }
      if (d.difference(today).inDays > 7) break;
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return out;
  }

  Cents get weekendAllowance {
    final days = upcomingWeekend;
    if (days.isEmpty) return 0;
    final today = dateOnly(now);
    final spentToday = spentOn(today);
    final perDay =
        max(0, freeBalance(current) + spentToday) ~/ daysLeftInclToday;
    var total = perDay * days.length;
    if (days.any((x) => sameDay(x, today))) total -= spentToday;
    return total;
  }

  /// Intensidade 0..1+ de cada dia do ciclo (gasto ÷ meta diária).
  double dayRatio(DateTime day) {
    final ideal = idealDaily(cycleOf(day));
    final spent = spentOn(day);
    if (ideal <= 0) return spent > 0 ? 2 : 0;
    return spent / ideal;
  }

  bool dayOnTrack(DateTime day) => dayRatio(day) <= 1.0;

  /// Dias seguidos dentro da meta, terminando hoje (se hoje ainda estiver ok)
  /// ou ontem. Só conta dias depois do primeiro uso do app.
  int get streak {
    final first = _firstActivity;
    if (first == null) return 0;
    var day = dateOnly(now);
    if (!dayOnTrack(day)) return 0;
    var count = 0;
    while (!day.isBefore(first) && dayOnTrack(day) && count < 999) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  DateTime? get _firstActivity {
    final dates = [...d.expenses.map((e) => e.createdAt)];
    if (d.salaries.isEmpty && dates.isEmpty) return null;
    if (dates.isEmpty) return dateOnly(now);
    return dateOnly(dates.reduce((a, b) => a.isBefore(b) ? a : b));
  }

  // ── Agregações ────────────────────────────────────────────

  /// Totais por categoria no ciclo, do maior para o menor.
  List<MapEntry<Category, Cents>> byCategory(Cycle c) {
    final m = <String, Cents>{};
    for (final e in expensesIn(c)) {
      m[e.category.id] = (m[e.category.id] ?? 0) + e.cents;
    }
    final list =
        m.entries.map((e) => MapEntry(categoryById(e.key), e.value)).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  List<Expense> subscriptions(Cycle c) =>
      expensesIn(c).where((e) => e.categoryId == 'assinaturas').toList()
        ..sort((a, b) => b.cents.compareTo(a.cents));

  /// Últimos [n] ciclos (mais antigo primeiro).
  List<Cycle> lastCycles(int n) =>
      List.generate(n, (i) => fromKey(current.key - (n - 1 - i)));
}
