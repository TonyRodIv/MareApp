import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mare/core/cycle.dart';
import 'package:mare/core/money.dart';
import 'package:mare/data/finance.dart';
import 'package:mare/data/models.dart';
import 'package:mare/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

int key(int y, int m) => y * 12 + (m - 1);

Expense exp(String name, int cents, DateTime date, {Recurrence rec = Recurrence.once, DateTime? end, DateTime? createdAt}) =>
    Expense(name: name, cents: cents, categoryId: 'outros', date: date, recurrence: rec, endDate: end, createdAt: createdAt);

Caixinha box({required int createdKey, PlanMode mode = PlanMode.fixed, int amount = 10000, List<Movement>? moves}) => Caixinha(
  name: 'Viagem',
  icon: 'piggy',
  color: 0xFF144A54,
  createdKey: createdKey,
  plans: [ContributionPlan(createdKey, mode, amount)],
  movements: moves,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('Cycle', () {
    test('ciclo começa no dia de virada e termina (exclusivo) na próxima', () {
      final c = Cycle.of(DateTime(2026, 3, 20), 15);
      expect(c.start, DateTime(2026, 3, 15));
      expect(c.end, DateTime(2026, 4, 15));
      expect(c.key, key(2026, 3));
      expect(c.contains(DateTime(2026, 4, 14)), isTrue);
      expect(c.contains(DateTime(2026, 4, 15)), isFalse);
    });

    test('data antes do dia de virada pertence ao ciclo anterior (inclusive virando o ano)', () {
      final c = Cycle.of(DateTime(2026, 1, 10), 15);
      expect(c.start, DateTime(2025, 12, 15));
      expect(c.end, DateTime(2026, 1, 15));
      expect(c.key, key(2025, 12));
    });

    test('dia de virada 31 é limitado ao tamanho do mês', () {
      final feb = Cycle.of(DateTime(2026, 2, 28), 31);
      expect(feb.start, DateTime(2026, 2, 28));
      expect(feb.end, DateTime(2026, 3, 31));
      final jan = Cycle.of(DateTime(2026, 2, 27), 31);
      expect(jan.start, DateTime(2026, 1, 31));
      expect(jan.end, DateTime(2026, 2, 28));
      final leap = Cycle.of(DateTime(2024, 2, 29), 31);
      expect(leap.start, DateTime(2024, 2, 29));
    });

    test('ciclos consecutivos não têm buraco nem sobreposição', () {
      for (final sd in [1, 15, 29, 30, 31]) {
        var c = Cycle.of(DateTime(2025, 1, 1), sd);
        for (var i = 0; i < 30; i++) {
          final n = c.next(sd);
          expect(n.start, c.end, reason: 'startDay $sd, ${c.start}');
          expect(n.key, c.key + 1);
          expect(Cycle.of(c.end.subtract(const Duration(days: 1)), sd).key, c.key);
          c = n;
        }
      }
    });

    test('fromKey é inverso de key', () {
      final c = Cycle.fromKey(key(2026, 7), 10);
      expect(c.start, DateTime(2026, 7, 10));
      expect(c.key, key(2026, 7));
      expect(c.lengthInDays, 31);
    });
  });

  group('Vigência de gastos', () {
    final f = Finance(AppData(cycleStartDay: 10), now: DateTime(2026, 3, 15));
    test('gasto único só vale no ciclo da sua data', () {
      final e = exp('Mercado', 5000, DateTime(2026, 3, 12));
      expect(f.expenseActive(e, f.fromKey(key(2026, 3))), isTrue);
      expect(f.expenseActive(e, f.fromKey(key(2026, 2))), isFalse);
      expect(f.expenseActive(e, f.fromKey(key(2026, 4))), isFalse);
      // dia 5 de março ainda é ciclo de fevereiro (virada no dia 10)
      final early = exp('x', 1, DateTime(2026, 3, 5));
      expect(f.expenseActive(early, f.fromKey(key(2026, 2))), isTrue);
      expect(f.expenseActive(early, f.fromKey(key(2026, 3))), isFalse);
    });

    test('mensal sem fim vale para sempre a partir do ciclo da data', () {
      final e = exp('Netflix', 4000, DateTime(2026, 3, 12), rec: Recurrence.monthly);
      expect(f.expenseActive(e, f.fromKey(key(2026, 2))), isFalse);
      expect(f.expenseActive(e, f.fromKey(key(2026, 3))), isTrue);
      expect(f.expenseActive(e, f.fromKey(key(2030, 1))), isTrue);
    });

    test('mensal com fim vale até o ciclo do endDate (inclusive)', () {
      final e = exp('Curso', 4000, DateTime(2026, 3, 12), rec: Recurrence.monthly, end: DateTime(2026, 5, 20));
      expect(f.expenseActive(e, f.fromKey(key(2026, 3))), isTrue);
      expect(f.expenseActive(e, f.fromKey(key(2026, 5))), isTrue);
      expect(f.expenseActive(e, f.fromKey(key(2026, 6))), isFalse);
    });
  });

  group('Salário', () {
    test('salário tem histórico por vigência', () {
      final d = AppData(salaries: [SalaryEntry(key(2026, 1), 300000), SalaryEntry(key(2026, 3), 400000)]);
      final f = Finance(d, now: DateTime(2026, 3, 15));
      expect(f.salaryFor(f.fromKey(key(2025, 12))), 0);
      expect(f.salaryFor(f.fromKey(key(2026, 2))), 300000);
      expect(f.salaryFor(f.fromKey(key(2026, 3))), 400000);
      expect(f.salary, 400000);
    });
  });

  group('Caixinha', () {
    final now = DateTime(2026, 3, 15);

    test('saldo acumula aportes de todos os ciclos', () {
      final d = AppData(boxes: [box(createdKey: key(2026, 1))]);
      final f = Finance(d, now: now);
      expect(f.boxBalance(d.boxes.first), 30000);
      expect(f.boxBalance(d.boxes.first, upTo: f.fromKey(key(2026, 1))), 10000);
    });

    test('aporte percentual usa o salário de cada ciclo', () {
      final d = AppData(
        salaries: [SalaryEntry(key(2026, 1), 400000), SalaryEntry(key(2026, 2), 500000)],
        boxes: [box(createdKey: key(2026, 1), mode: PlanMode.percent, amount: 1000)], // 10%
      );
      final f = Finance(d, now: now);
      // jan 40.000 + fev 50.000 + mar 50.000
      expect(f.boxBalance(d.boxes.first), 140000);
    });

    test('gasto único da caixinha não reaparece nos ciclos seguintes', () {
      final spend = Movement(name: 'Passagem', cents: 5000, type: MovementType.spend, date: DateTime(2026, 1, 20));
      final d = AppData(boxes: [box(createdKey: key(2026, 1), moves: [spend])]);
      final f = Finance(d, now: now);
      final b = d.boxes.first;
      expect(f.boxBalance(b, upTo: f.fromKey(key(2026, 1))), 5000);
      expect(f.boxBalance(b, upTo: f.fromKey(key(2026, 2))), 15000);
      expect(f.boxBalance(b), 25000);
    });

    test('depósito soma, resgate subtrai, gasto recorrente se repete', () {
      final d = AppData(
        boxes: [
          box(
            createdKey: key(2026, 1),
            amount: 0,
            moves: [
              Movement(name: 'Extra', cents: 20000, type: MovementType.deposit, date: DateTime(2026, 1, 5)),
              Movement(name: 'Resgate', cents: 3000, type: MovementType.redeem, date: DateTime(2026, 2, 5)),
              Movement(name: 'Streaming', cents: 1000, type: MovementType.spend, date: DateTime(2026, 1, 8), recurrence: Recurrence.monthly),
            ],
          ),
        ],
      );
      final f = Finance(d, now: now);
      expect(f.boxBalance(d.boxes.first), 20000 - 3000 - 3 * 1000);
    });

    test('saldo livre = salário − gastos − aportes − depósitos + resgates', () {
      final d = AppData(
        salaries: [SalaryEntry(key(2026, 3), 500000)],
        expenses: [
          exp('Único', 10000, DateTime(2026, 3, 3)),
          exp('Fixo', 20000, DateTime(2026, 1, 3), rec: Recurrence.monthly),
        ],
        boxes: [
          box(
            createdKey: key(2026, 3),
            amount: 30000,
            moves: [
              Movement(name: 'Dep', cents: 5000, type: MovementType.deposit, date: DateTime(2026, 3, 4)),
              Movement(name: 'Res', cents: 2000, type: MovementType.redeem, date: DateTime(2026, 3, 5)),
              Movement(name: 'Gasto da caixinha', cents: 999, type: MovementType.spend, date: DateTime(2026, 3, 6)),
            ],
          ),
        ],
      );
      final f = Finance(d, now: now);
      final c = f.current;
      expect(f.expensesTotal(c), 30000);
      expect(f.fixedTotal(c), 20000);
      expect(f.variableTotal(c), 10000);
      expect(f.contributionsTotal(c), 30000);
      expect(f.freeBalance(c), 500000 - 30000 - 30000 - 5000 + 2000);
    });

    test('closeBox resgata o saldo inteiro e para os aportes', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await Store.load();
      store.addBox(name: 'Reserva', icon: 'piggy', color: 0xFF144A54, mode: PlanMode.fixed, amount: 10000);
      final b = store.data.boxes.first;
      store.addMovement(b.id, Movement(name: 'Extra', cents: 5000, type: MovementType.deposit, date: DateTime.now()));
      expect(store.f.boxBalance(b), 15000);
      final freeBefore = store.f.freeBalance(store.cycle);
      store.closeBox(b.id);
      expect(b.isOpen, isFalse);
      expect(b.closedKey, store.cycle.key);
      expect(b.movements.last.type, MovementType.redeem);
      expect(b.movements.last.cents, 15000);
      expect(store.f.boxBalance(b), 0);
      expect(store.f.freeBalance(store.cycle), freeBefore + 15000);
      final next = store.cycle.next(store.data.cycleStartDay);
      expect(store.f.contributionFor(b, next), 0);
      expect(store.f.boxBalance(b, upTo: next), 0);
    });
  });

  group('Store', () {
    late Store store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = await Store.load();
    });

    test('updateExpense: mudar valor de recorrente antigo preserva histórico', () {
      final cur = store.cycle;
      final prev = cur.prev(store.data.cycleStartDay);
      final e = exp('Academia', 10000, prev.start, rec: Recurrence.monthly);
      store.addExpense(e);
      final edited = e.copy()..cents = 15000;
      store.updateExpense(edited);

      expect(store.data.expenses.length, 2);
      final f = store.f;
      expect(f.expensesTotal(prev), 10000);
      expect(f.expensesTotal(cur), 15000);
      expect(f.expensesTotal(cur.next(store.data.cycleStartDay)), 15000);
      final old = store.data.expenses.firstWhere((x) => x.id == e.id);
      expect(f.cycleOf(old.endDate!).key, prev.key);
    });

    test('updateExpense: recorrente criado neste ciclo é editado no lugar', () {
      final e = exp('Academia', 10000, store.cycle.start, rec: Recurrence.monthly);
      store.addExpense(e);
      store.updateExpense(e.copy()..cents = 12000);
      expect(store.data.expenses.length, 1);
      expect(store.data.expenses.first.cents, 12000);
    });

    test('updateExpense: gasto único é editado no lugar', () {
      final e = exp('Pizza', 5000, DateTime.now());
      store.addExpense(e);
      store.updateExpense(e.copy()..cents = 6000);
      expect(store.data.expenses.length, 1);
      expect(store.data.expenses.first.cents, 6000);
    });

    test('setSalary só afeta o ciclo atual em diante', () {
      final cur = store.cycle;
      final prev = cur.prev(store.data.cycleStartDay);
      store.data.salaries.add(SalaryEntry(prev.key, 300000));
      store.setSalary(400000);
      final f = store.f;
      expect(f.salaryFor(prev), 300000);
      expect(f.salaryFor(cur), 400000);
      expect(f.salaryFor(cur.next(store.data.cycleStartDay)), 400000);
    });

    test('finishOnboarding grava nome, salário e dia', () {
      store.finishOnboarding(name: '  Ana ', salary: 250000, startDay: 31);
      expect(store.data.userName, 'Ana');
      expect(store.data.onboardingDone, isTrue);
      expect(store.data.cycleStartDay, 31);
      expect(store.f.salary, 250000);
    });

    test('persiste e recarrega do SharedPreferences', () async {
      store.finishOnboarding(name: 'Ana', salary: 100000, startDay: 5);
      store.addExpense(exp('Pizza', 5000, DateTime.now()));
      final again = await Store.load();
      expect(again.data.userName, 'Ana');
      expect(again.data.expenses.single.cents, 5000);
    });

    test('importJson aceita backup do maré e rejeita lixo', () {
      final src = AppData(userName: 'Bia', salaries: [SalaryEntry(key(2026, 1), 1)]);
      expect(store.importJson(jsonEncode(src.toJson())), isNull);
      expect(store.data.userName, 'Bia');
      expect(store.importJson('isso não é json'), isNotNull);
      expect(store.importJson('{"foo":1}'), isNotNull);
    });
  });

  group('Importação legada (finapp_v3)', () {
    int keyOf(DateTime d) => Cycle.of(d, 1).key;
    final ms = DateTime(2026, 2, 10).millisecondsSinceEpoch;
    final raw = <String, dynamic>{
      'salary': 3000.5,
      'userName': 'Carla',
      'monthStartDay': 5,
      'expenses': [
        {'id': ms, 'name': 'Curso', 'value': 12.5, 'category': 'educacao', 'recurrence': 'until', 'untilDate': '2026-05-10', 'createdAt': ms},
        {'id': ms, 'name': 'Aluguel', 'value': 1000, 'category': 'moradia'},
        {'id': ms, 'name': 'Café', 'value': 8.9, 'category': 'alimentacao', 'recurrence': 'once', 'createdAt': ms},
      ],
      'caixinhas': [
        {
          'id': ms,
          'name': 'Viagem',
          'mode': 'percent',
          'amount': 10,
          'extras': [
            {'id': ms, 'name': 'Bônus', 'value': 50.5},
          ],
          'debts': [
            {'id': ms, 'name': 'Hotel', 'value': 20},
          ],
        },
      ],
    };

    test('converte reais em centavos, until em mensal com fim e itens antigos em mensal', () {
      final d = AppData.fromLegacy(raw, keyOf: keyOf);
      expect(d.onboardingDone, isTrue);
      expect(d.userName, 'Carla');
      expect(d.cycleStartDay, 5);
      expect(d.salaries.single.cents, 300050);

      final curso = d.expenses[0];
      expect(curso.cents, 1250);
      expect(curso.recurrence, Recurrence.monthly);
      expect(curso.endDate, DateTime(2026, 5, 10));

      final aluguel = d.expenses[1];
      expect(aluguel.cents, 100000);
      expect(aluguel.recurrence, Recurrence.monthly);
      expect(aluguel.endDate, isNull);

      final cafe = d.expenses[2];
      expect(cafe.cents, 890);
      expect(cafe.recurrence, Recurrence.once);
    });

    test('extras viram depósitos e dívidas viram gastos da caixinha', () {
      final d = AppData.fromLegacy(raw, keyOf: keyOf);
      final b = d.boxes.single;
      expect(b.plans.single.mode, PlanMode.percent);
      expect(b.plans.single.amount, 1000);
      final dep = b.movements.firstWhere((m) => m.type == MovementType.deposit);
      expect(dep.cents, 5050);
      final spend = b.movements.firstWhere((m) => m.type == MovementType.spend);
      expect(spend.cents, 2000);
      expect(spend.recurrence, Recurrence.monthly);
    });

    test('import via Store reconhece o formato antigo', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await Store.load();
      expect(store.importJson(jsonEncode({'finappBackupVersion': 3, 'data': raw})), isNull);
      expect(store.data.expenses.length, 3);
      expect(store.data.boxes.length, 1);
    });
  });

  group('JSON', () {
    test('toJson/fromJson preserva tudo', () {
      final d = AppData(
        userName: 'Dani',
        avatarPath: '/tmp/a.png',
        userSince: 2024,
        cycleStartDay: 17,
        theme: ThemePref.dark,
        hideValues: true,
        onboardingDone: true,
        salaries: [SalaryEntry(key(2026, 1), 300000), SalaryEntry(key(2026, 3), 350000)],
        expenses: [
          exp('Um', 1234, DateTime(2026, 3, 3), createdAt: DateTime(2026, 3, 3, 10)),
          exp('Dois', 5678, DateTime(2026, 1, 3), rec: Recurrence.monthly, end: DateTime(2026, 8, 1)),
        ],
        boxes: [
          Caixinha(
            name: 'Casa',
            icon: 'home',
            color: 0xFF165425,
            goalCents: 1000000,
            createdKey: key(2026, 1),
            closedKey: key(2026, 4),
            plans: [ContributionPlan(key(2026, 1), PlanMode.fixed, 5000), ContributionPlan(key(2026, 3), PlanMode.percent, 1250)],
            movements: [
              Movement(
                name: 'M',
                cents: 99,
                type: MovementType.redeem,
                date: DateTime(2026, 2, 2),
                recurrence: Recurrence.monthly,
                endDate: DateTime(2026, 6, 6),
              ),
            ],
          ),
        ],
        cards: [PayCard(name: 'Nu', last4: '1234', color: 0xFF8A0FD6, brand: CardBrand.visa)],
        cardSpans: {'saldo': 2, 'dia': 1},
      );
      final json = jsonEncode(d.toJson());
      final back = AppData.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(jsonEncode(back.toJson()), json);
      expect(back.userName, 'Dani');
      expect(back.cycleStartDay, 17);
      expect(back.theme, ThemePref.dark);
      expect(back.hideValues, isTrue);
      expect(back.salaries.length, 2);
      expect(back.expenses[1].endDate, DateTime(2026, 8, 1));
      expect(back.boxes.single.closedKey, key(2026, 4));
      expect(back.boxes.single.plans.last.mode, PlanMode.percent);
      expect(back.boxes.single.movements.single.type, MovementType.redeem);
      expect(back.cards.single.brand, CardBrand.visa);
      expect(back.cardSpans, {'saldo': 2, 'dia': 1});
    });

    test('fromJson é tolerante a campos ausentes', () {
      final back = AppData.fromJson({});
      expect(back.cycleStartDay, 1);
      expect(back.expenses, isEmpty);
      expect(AppData.fromJson({'cycleStartDay': 99}).cycleStartDay, 31);
    });
  });

  group('Dinheiro', () {
    test('fmtMoney formata em pt_BR', () {
      expect(fmtMoney(123456), 'R\$ 1.234,56');
      expect(fmtMoney(0), 'R\$ 0,00');
      expect(fmtMoney(5), 'R\$ 0,05');
      expect(fmtMoney(1, hidden: true), 'R\$ •••••');
      expect(fmtNumber(123456), '1.234,56');
    });

    test('parseMoney entende formatos brasileiros e simples', () {
      expect(parseMoney('12,50'), 1250);
      expect(parseMoney('12.5'), 1250);
      expect(parseMoney('1.234,56'), 123456);
      expect(parseMoney('R\$ 10'), 1000);
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
    });

    test('centavos inteiros evitam erro de ponto flutuante', () {
      expect(parseMoney('0,10')! + parseMoney('0,20')!, parseMoney('0,30'));
      expect(centsFromLegacy(0.1 + 0.2), 30);
      expect(centsFromLegacy('19.99'), 1999);
    });
  });

  group('Ritmo do dia', () {
    final now = DateTime(2026, 3, 15, 12);

    test('todayAllowance divide o saldo livre pelos dias restantes', () {
      final d = AppData(salaries: [SalaryEntry(key(2026, 3), 340000)]);
      final f = Finance(d, now: now);
      expect(f.daysLeftInclToday, 17); // 15..31 de março
      expect(f.todayAllowance, 20000);
    });

    test('gasto de hoje reduz o que ainda pode ser gasto hoje', () {
      final d = AppData(salaries: [SalaryEntry(key(2026, 3), 340000)], expenses: [exp('Almoço', 5000, DateTime(2026, 3, 15))]);
      final f = Finance(d, now: now);
      expect(f.spentOn(DateTime(2026, 3, 15)), 5000);
      expect(f.todayAllowance, 15000);
    });

    test('streak: zero sem dados, conta dias dentro da meta e quebra no estouro', () {
      expect(Finance(AppData(), now: now).streak, 0);

      final d = AppData(
        salaries: [SalaryEntry(key(2026, 3), 310000)],
        expenses: [exp('Estouro', 50000, DateTime(2026, 3, 12), createdAt: DateTime(2026, 3, 10))],
      );
      final f = Finance(d, now: now);
      expect(f.idealDaily(f.current), 10000);
      expect(f.dayOnTrack(DateTime(2026, 3, 12)), isFalse);
      expect(f.streak, 3); // 15, 14 e 13

      final calm = AppData(
        salaries: [SalaryEntry(key(2026, 3), 310000)],
        expenses: [exp('Café', 1000, DateTime(2026, 3, 12), createdAt: DateTime(2026, 3, 10))],
      );
      expect(Finance(calm, now: now).streak, 6); // 10..15
    });
  });
}
