import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mare/data/models.dart';
import 'package:mare/data/store.dart';
import 'package:mare/main.dart';
import 'package:mare/ui/widgets/kit.dart';
import 'package:mare/ui/widgets/nav_keypad.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Avança o relógio em passos curtos. Não usamos pumpAndSettle porque o fundo
/// do onboarding (TideBackground) anima para sempre.
Future<void> settle(WidgetTester t, [int ms = 900]) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapText(WidgetTester t, String text, {Finder? within}) async {
  var f = find.text(text);
  if (within != null) f = find.descendant(of: within, matching: f);
  expect(f, findsWidgets, reason: 'texto "$text" não encontrado');
  await t.ensureVisible(f.first);
  await t.tap(f.first);
  await settle(t);
}

Future<void> keypad(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    final f = find.descendant(of: find.byType(Keypad), matching: find.text(d));
    await t.tap(f.first);
    await t.pump(const Duration(milliseconds: 50));
  }
  await settle(t, 200);
}

Future<void> runFlow(WidgetTester tester, Size size, double dpr) async {
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final store = await Store.load();
  await tester.pumpWidget(MareApp(store: store));
  await settle(tester, 1500);
  expect(tester.takeException(), isNull);

  // Onboarding
  await tapText(tester, 'Começar');
  await settle(tester, 500);
  await tester.enterText(find.byType(CupertinoTextField).first, 'Marina');
  await settle(tester, 200);
  await tapText(tester, 'Continuar'); // nome
  await settle(tester, 500);
  await tapText(tester, 'Agora não'); // foto de perfil opcional
  await settle(tester, 500);
  await tapText(tester, 'Continuar'); // cor destaque
  await settle(tester, 500);
  await keypad(tester, '500000'); // R$ 5.000,00
  await tapText(tester, 'Continuar'); // salário
  await settle(tester, 500);
  await tapText(tester, 'Continuar'); // dia de virada
  await settle(tester, 500);
  expect(tester.takeException(), isNull);
  await tapText(tester, 'Entrar no app');
  await settle(tester, 900);
  expect(tester.takeException(), isNull);

  expect(store.data.onboardingDone, isTrue);
  expect(store.data.userName, 'Marina');
  expect(store.f.salary, 500000);
  expect(find.text('Contas'), findsNothing); // oculto quando nenhuma conta foi adicionada

  // Shell: as 4 abas
  for (final label in ['Extrato', 'Caixinhas', 'Seu Perfil', 'Carteira']) {
    await tapText(tester, label);
    await settle(tester, 600);
    expect(tester.takeException(), isNull, reason: 'aba $label');
  }

  // Adicionar gasto pelo botão "Gastos"
  await tester.tap(find.widgetWithText(CircleAction, 'Gasto').first);
  await settle(tester, 900);
  await keypad(tester, '2590'); // R$ 25,90
  await tapText(tester, 'Continuar');
  await settle(tester, 700);
  await tester.enterText(find.byType(CupertinoTextField).first, 'Almoço');
  await settle(tester, 200);
  await tapText(tester, 'Continuar');
  await settle(tester, 700);
  await tapText(tester, 'Continuar');
  await settle(tester, 700);
  expect(tester.takeException(), isNull);
  await tapText(tester, 'Salvar gasto');
  await settle(tester, 1200);
  expect(tester.takeException(), isNull);
  expect(store.data.expenses.length, 1);
  expect(store.data.expenses.single.cents, 2590);
  expect(store.data.expenses.single.name, 'Almoço');

  // Criar caixinha (fluxo passo a passo)
  await tester.tap(find.widgetWithText(CircleAction, 'Caixinha').first);
  await settle(tester, 600);
  await keypad(tester, '10000'); // R$ 100,00 por ciclo
  await tapText(tester, 'Continuar');
  await settle(tester, 500);
  await tester.enterText(find.byType(CupertinoTextField).first, 'Viagem');
  await settle(tester, 200);
  await tapText(tester, 'Continuar');
  await settle(tester, 500);
  await tapText(tester, 'Continuar'); // visual
  await settle(tester, 500);
  await tapText(tester, 'Criar caixinha'); // meta opcional
  await settle(tester, 900);
  expect(tester.takeException(), isNull);
  expect(store.data.boxes.length, 1);
  expect(store.data.boxes.single.name, 'Viagem');
  expect(store.f.contributionFor(store.data.boxes.single, store.cycle), 10000);

  // Revisita todas as abas com dados
  for (final label in ['Extrato', 'Caixinhas', 'Seu Perfil', 'Carteira']) {
    await tapText(tester, label);
    await settle(tester, 600);
    expect(tester.takeException(), isNull, reason: 'aba $label com dados');
  }

  // Desmonta o app e deixa os timers terminarem.
  await tester.pumpWidget(const SizedBox());
  await settle(tester, 300);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('fluxo completo no celular (390x844)', (tester) async {
    await runFlow(tester, const Size(390, 844), 1.0);
  });

  testWidgets('fluxo completo no tablet (1024x1366)', (tester) async {
    await runFlow(tester, const Size(1024, 1366), 1.0);
  });

  testWidgets('app já configurado abre direto na carteira', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = await Store.load();
    store.finishOnboarding(name: 'Rafa', salary: 300000, startDay: 1);
    store.addExpense(Expense(name: 'Mercado', cents: 15000, categoryId: 'alimentacao', date: DateTime.now()));
    await tester.pumpWidget(MareApp(store: store));
    await settle(tester, 1500);
    expect(find.text('Carteira'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 300);
  });
}
