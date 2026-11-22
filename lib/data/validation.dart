import '../core/cycle.dart';
import '../core/money.dart';
import 'finance.dart';
import 'models.dart';

/// Limites e invariantes financeiros do app.
/// Toda entrada do usuário, importação de backup e carga local passa por aqui
/// para impedir valores absurdos, datas invertidas ou caixinhas negativas.
abstract final class MoneyLimits {
  /// R$ 999.999.999,00 em centavos — evita overflow e valores irreais.
  static const Cents maxCents = 99999999900;
  static const Cents minPositiveCents = 1;

  /// Percentual do salário em basis points (100 = 1%, 10000 = 100%).
  static const int minPercentBp = 100;
  static const int maxPercentBp = 10000;

  static const int minCycleDay = 1;
  static const int maxCycleDay = 31;

  static final DateTime minDate = DateTime(2000, 1, 1);
  static final DateTime maxDate = DateTime(2100, 12, 31);
}

DateTime clampDate(DateTime d) {
  if (d.isBefore(MoneyLimits.minDate)) return MoneyLimits.minDate;
  if (d.isAfter(MoneyLimits.maxDate)) return MoneyLimits.maxDate;
  return d;
}

String? validateSalary(Cents cents) {
  if (cents < 0) return 'O salário não pode ser negativo.';
  if (cents > MoneyLimits.maxCents) return 'Valor de salário acima do limite.';
  return null;
}

String? validateExpense(Expense e, {Set<String>? validCardIds}) {
  final name = e.name.trim();
  if (name.isEmpty) return 'Informe um nome para o gasto.';
  if (e.cents < MoneyLimits.minPositiveCents) {
    return 'O valor do gasto deve ser maior que zero.';
  }
  if (e.cents > MoneyLimits.maxCents) {
    return 'O valor do gasto ultrapassa o limite permitido.';
  }
  if (e.isRecurring && e.endDate != null && dateOnly(e.endDate!).isBefore(dateOnly(e.date))) {
    return 'A data final não pode ser anterior à data inicial.';
  }
  if (validCardIds != null && e.cardId != null && !validCardIds.contains(e.cardId)) {
    e.cardId = null;
  }
  return null;
}

void normalizeExpense(Expense e, {Set<String>? validCardIds}) {
  e.name = e.name.trim();
  if (e.name.length > 40) e.name = e.name.substring(0, 40).trim();
  e.cents = e.cents.clamp(MoneyLimits.minPositiveCents, MoneyLimits.maxCents);
  e.categoryId = categoryById(e.categoryId).id;
  e.date = clampDate(e.date);
  if (!e.isRecurring) {
    e.endDate = null;
  } else if (e.endDate != null) {
    e.endDate = clampDate(e.endDate!);
    if (dateOnly(e.endDate!).isBefore(dateOnly(e.date))) {
      e.endDate = e.date;
    }
  }
  if (validCardIds != null && e.cardId != null && !validCardIds.contains(e.cardId)) {
    e.cardId = null;
  }
}

String? validateBoxParams({
  required String name,
  required PlanMode mode,
  required int amount,
  Cents? goal,
}) {
  if (name.trim().isEmpty) return 'Informe um nome para a caixinha.';
  if (mode == PlanMode.fixed) {
    if (amount < MoneyLimits.minPositiveCents) {
      return 'O aporte da caixinha deve ser maior que zero.';
    }
    if (amount > MoneyLimits.maxCents) {
      return 'O aporte ultrapassa o limite permitido.';
    }
  } else {
    if (amount < MoneyLimits.minPercentBp || amount > MoneyLimits.maxPercentBp) {
      return 'O percentual deve ficar entre 1% e 100% do salário.';
    }
  }
  if (goal != null && goal > 0 && goal > MoneyLimits.maxCents) {
    return 'A meta ultrapassa o limite permitido.';
  }
  return null;
}

/// Calcula o saldo máximo disponível na [box] para uma saída ([spend] ou [redeem]),
/// desconsiderando [excludingMovementId] quando estiver editando uma movimentação existente.
Cents availableBoxBalance(
  Finance f,
  Caixinha box, {
  String? excludingMovementId,
}) {
  if (excludingMovementId == null) return f.boxBalance(box);
  final copy = Caixinha.fromJson(box.toJson());
  copy.movements.removeWhere((m) => m.id == excludingMovementId);
  return f.boxBalance(copy);
}

/// Valida uma movimentação de caixinha (nova ou editada), impedindo que a
/// caixinha fique negativa em qualquer cenário.
String? validateMovement(
  Finance f,
  Caixinha? box,
  Movement m, {
  String? replacingId,
}) {
  if (box == null) return 'Caixinha não encontrada.';
  if (!box.isOpen) return 'Esta caixinha já foi encerrada.';
  if (m.cents < MoneyLimits.minPositiveCents) {
    return 'O valor deve ser maior que zero.';
  }
  if (m.cents > MoneyLimits.maxCents) {
    return 'O valor ultrapassa o limite permitido.';
  }
  final rec = m.type == MovementType.spend ? m.recurrence : Recurrence.once;
  if (rec == Recurrence.monthly &&
      m.endDate != null &&
      dateOnly(m.endDate!).isBefore(dateOnly(m.date))) {
    return 'A data final não pode ser anterior à data inicial.';
  }

  // Simula a caixinha com a movimentação aplicada para impedir saldo negativo.
  final sim = Caixinha.fromJson(box.toJson());
  if (replacingId != null) {
    sim.movements.removeWhere((x) => x.id == replacingId);
  }
  final normalized = Movement.fromJson(m.toJson());
  normalizeMovement(normalized);
  sim.movements.add(normalized);

  if (m.sign < 0) {
    final avail = availableBoxBalance(
      f,
      box,
      excludingMovementId: replacingId,
    );
    final rawAfter = f.boxRawBalance(sim);
    if (rawAfter < 0) {
      if (avail <= 0) {
        return 'Saldo insuficiente na caixinha (disponível: R\$ 0,00).';
      }
      return 'Saldo insuficiente na caixinha (disponível: ${fmtMoney(avail)}).';
    }
  }
  return null;
}

void normalizeMovement(Movement m) {
  m.name = m.name.trim();
  if (m.name.isEmpty) {
    m.name = switch (m.type) {
      MovementType.deposit => 'Extra',
      MovementType.spend => 'Gasto',
      MovementType.redeem => 'Resgate',
    };
  }
  if (m.name.length > 40) m.name = m.name.substring(0, 40).trim();
  m.cents = m.cents.clamp(MoneyLimits.minPositiveCents, MoneyLimits.maxCents);
  m.date = clampDate(m.date);
  if (m.type != MovementType.spend) {
    m.recurrence = Recurrence.once;
    m.endDate = null;
  } else if (m.recurrence != Recurrence.monthly) {
    m.endDate = null;
  } else if (m.endDate != null) {
    m.endDate = clampDate(m.endDate!);
    if (dateOnly(m.endDate!).isBefore(dateOnly(m.date))) {
      m.endDate = m.date;
    }
  }
}

String? validateCard(PayCard c) {
  if (c.name.trim().isEmpty) return 'Informe o nome da conta ou banco.';
  final last4 = c.last4.trim();
  if (last4.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(last4)) {
    return 'Os últimos dígitos devem ter exatamente 4 números.';
  }
  return null;
}

void normalizeCard(PayCard c) {
  c.name = c.name.trim();
  if (c.name.length > 20) c.name = c.name.substring(0, 20).trim();
  c.last4 = c.last4.replaceAll(RegExp(r'\D'), '');
  if (c.last4.length > 4) c.last4 = c.last4.substring(0, 4);
}

/// Sanitiza toda a árvore [AppData] ao carregar do disco ou importar backups,
/// garantindo que dados antigos ou malformados nunca quebrem os cálculos.
void sanitizeAppData(AppData d) {
  d.cycleStartDay = d.cycleStartDay.clamp(
    MoneyLimits.minCycleDay,
    MoneyLimits.maxCycleDay,
  );
  d.userName = d.userName.trim();

  // Salários: sem valores negativos ou fora do limite, ordenados por vigência.
  d.salaries = [
    for (final s in d.salaries)
      SalaryEntry(s.fromKey, s.cents.clamp(0, MoneyLimits.maxCents)),
  ]..sort((a, b) => a.fromKey.compareTo(b.fromKey));

  // Cartões
  d.cards.removeWhere((c) => c.name.trim().isEmpty);
  for (final c in d.cards) {
    normalizeCard(c);
  }
  final cardIds = d.cards.map((c) => c.id).toSet();

  // Gastos
  d.expenses.removeWhere((e) => e.cents <= 0);
  for (final e in d.expenses) {
    if (e.name.trim().isEmpty) e.name = categoryById(e.categoryId).label;
    normalizeExpense(e, validCardIds: cardIds);
  }

  // Caixinhas
  d.boxes.removeWhere((b) => b.name.trim().isEmpty);
  for (final b in d.boxes) {
    b.name = b.name.trim();
    if (!boxIcons.containsKey(b.icon)) b.icon = 'piggy';
    if (b.goalCents != null && b.goalCents! <= 0) {
      b.goalCents = null;
    } else if (b.goalCents != null && b.goalCents! > MoneyLimits.maxCents) {
      b.goalCents = MoneyLimits.maxCents;
    }
    if (b.plans.isEmpty) {
      b.plans.add(ContributionPlan(b.createdKey, PlanMode.fixed, 0));
    } else {
      for (var i = 0; i < b.plans.length; i++) {
        final p = b.plans[i];
        final amt = p.mode == PlanMode.percent
            ? p.amount.clamp(0, MoneyLimits.maxPercentBp)
            : p.amount.clamp(0, MoneyLimits.maxCents);
        b.plans[i] = ContributionPlan(p.fromKey, p.mode, amt);
      }
      b.plans.sort((a, b2) => a.fromKey.compareTo(b2.fromKey));
    }
    b.movements.removeWhere((m) => m.cents <= 0);
    for (final m in b.movements) {
      normalizeMovement(m);
    }
  }
}
