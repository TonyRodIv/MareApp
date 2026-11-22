import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/money.dart';
import 'brands.dart';

final _rnd = Random();

/// IDs únicos de verdade (compatível com VM 64-bit e Web JS 32-bit).
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(0x3FFFFFFF).toRadixString(36)}';

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;
String? _iso(DateTime? d) => d?.toIso8601String();

// ── Categorias ──────────────────────────────────────────────

class Category {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<String> keywords; // para sugerir a categoria pelo nome do gasto
  const Category(this.id, this.label, this.icon, this.color, this.keywords);
}

const categories = <Category>[
  Category(
    'alimentacao',
    'Alimentação',
    LucideIcons.utensils,
    Color(0xFFFF6259),
    [
      'mercado',
      'super',
      'ifood',
      'restaurante',
      'lanche',
      'padaria',
      'almoço',
      'almoco',
      'jantar',
      'café',
      'cafe',
      'pizza',
      'açougue',
      'feira',
    ],
  ),
  Category('transporte', 'Transporte', LucideIcons.car, Color(0xFF3395FF), [
    'uber',
    '99',
    'corrida',
    'gasolina',
    'combustível',
    'combustivel',
    'ônibus',
    'onibus',
    'metrô',
    'metro',
    'estacionamento',
    'pedágio',
    'taxi',
    'táxi',
  ]),
  Category('moradia', 'Moradia', LucideIcons.house, Color(0xFF5DD27A), [
    'aluguel',
    'condomínio',
    'condominio',
    'iptu',
    'reforma',
    'móveis',
    'moveis',
  ]),
  Category('contas', 'Contas', LucideIcons.receipt, Color(0xFFFFD633), [
    'luz',
    'energia',
    'água',
    'agua',
    'internet',
    'gás',
    'gas',
    'telefone',
    'celular',
    'fatura',
    'boleto',
  ]),
  Category('saude', 'Saúde', LucideIcons.heartPulse, Color(0xFFBF75E5), [
    'farmácia',
    'farmacia',
    'remédio',
    'remedio',
    'médico',
    'medico',
    'consulta',
    'exame',
    'plano de saúde',
    'dentista',
    'academia',
  ]),
  Category(
    'educacao',
    'Educação',
    LucideIcons.graduationCap,
    Color(0xFF7978DE),
    ['curso', 'faculdade', 'escola', 'livro', 'mensalidade', 'udemy', 'alura'],
  ),
  Category('lazer', 'Lazer', LucideIcons.ticket, Color(0xFFFFAA33), [
    'lazer',
    'cinema',
    'show',
    'bar',
    'festa',
    'passeio',
    'ingresso',
    'entretenimento',
    'teatro',
    'boliche',
    'parque',
  ]),
  Category('jogos', 'Jogos', LucideIcons.gamepad2, Color(0xFF9B6BFF), [
    'jogo',
    'jogos',
    'game',
    'games',
    'nintendo',
    'switch',
    'playstation',
    'xbox',
    'steam',
    'controle',
    'console',
  ]),
  Category('viagem', 'Viagens', LucideIcons.plane, Color(0xFF38BDF8), [
    'viagem',
    'hotel',
    'pousada',
    'passagem',
    'aerea',
    'voo',
    'airbnb',
    'booking',
    'decolar',
    'hospedagem',
  ]),
  Category('compras', 'Compras', LucideIcons.shoppingBag, Color(0xFF5BBDEB), [
    'shopee',
    'amazon',
    'mercado livre',
    'loja',
    'presente',
    'compras',
  ]),
  Category('tecnologia', 'Tecnologia', LucideIcons.laptop, Color(0xFF60A5FA), [
    'eletronico',
    'notebook',
    'computador',
    'celular',
    'smartphone',
    'tablet',
    'teclado',
    'mouse',
    'monitor',
    'fone',
    'setup',
    'tech',
    'kabum',
    'pichau',
    'apple',
  ]),
  Category('assinaturas', 'Assinaturas', LucideIcons.tv, Color(0xFF59C0D2), [
    'netflix',
    'spotify',
    'prime',
    'disney',
    'hbo',
    'max',
    'youtube',
    'icloud',
    'chatgpt',
    'claude',
    'assinatura',
    'globoplay',
    'deezer',
  ]),
  Category('moda', 'Moda e Beleza', LucideIcons.shirt, Color(0xFFFF6482), [
    'roupa',
    'tenis',
    'salao',
    'cabelo',
    'maquiagem',
    'perfume',
    'barbearia',
    'shein',
  ]),
  Category('pets', 'Pets', LucideIcons.pawPrint, Color(0xFFF59E0B), [
    'pet',
    'racao',
    'veterinario',
    'cachorro',
    'gato',
    'petshop',
    'cobasi',
    'petz',
  ]),
  Category('outros', 'Outros', LucideIcons.ellipsis, Color(0xFF33D2CB), []),
];

Category categoryById(String? id) {
  const legacy = {'vestuario': 'moda'};
  final key = legacy[id] ?? id;
  return categories.firstWhere(
    (c) => c.id == key,
    orElse: () => categories.last,
  );
}

/// Sugere a categoria a partir do nome digitado ("Nintendo" → Lazer, "Uber pra casa" → Transporte).
Category? guessCategory(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return null;
  final smartId = smartCategoryIdFor(trimmed);
  if (smartId != null) return categoryById(smartId);
  final n = foldText(trimmed);
  for (final c in categories) {
    for (final k in c.keywords) {
      if (RegExp('(^|[^a-z0-9])${RegExp.escape(foldText(k))}').hasMatch(n)) {
        return c;
      }
    }
  }
  return null;
}

// ── Recorrência ─────────────────────────────────────────────

enum Recurrence { once, monthly }

Recurrence _rec(dynamic v) =>
    v == 'monthly' || v == 'until' ? Recurrence.monthly : Recurrence.once;

// ── Gasto ───────────────────────────────────────────────────

class Expense {
  final String id;
  String name;
  Cents cents;
  String categoryId;
  String? cardId;

  /// Único: dia do gasto. Recorrente: primeiro dia em que vale.
  DateTime date;
  Recurrence recurrence;

  /// Recorrente: último dia em que ainda vale (inclusivo). null = sem fim.
  DateTime? endDate;
  DateTime createdAt;

  Expense({
    String? id,
    required this.name,
    required this.cents,
    required this.categoryId,
    required this.date,
    this.recurrence = Recurrence.once,
    this.endDate,
    this.cardId,
    DateTime? createdAt,
  }) : id = id ?? newId(),
       createdAt = createdAt ?? DateTime.now();

  bool get isRecurring => recurrence == Recurrence.monthly;
  Category get category => categoryById(categoryId);

  Expense copy() => Expense.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cents': cents,
    'categoryId': categoryId,
    'cardId': cardId,
    'date': _iso(date),
    'recurrence': recurrence.name,
    'endDate': _iso(endDate),
    'createdAt': _iso(createdAt),
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    cents: (j['cents'] as num?)?.toInt() ?? 0,
    categoryId: j['categoryId'] as String? ?? 'outros',
    cardId: j['cardId'] as String?,
    date: _date(j['date']) ?? DateTime.now(),
    recurrence: j['recurrence'] == 'monthly'
        ? Recurrence.monthly
        : Recurrence.once,
    endDate: _date(j['endDate']),
    createdAt: _date(j['createdAt']),
  );
}

// ── Caixinha ────────────────────────────────────────────────

enum PlanMode { fixed, percent }

/// Quanto a caixinha recebe por ciclo, a partir de um ciclo.
/// Guardar o histórico de planos evita que mudar o aporte hoje reescreva o
/// saldo acumulado nos meses anteriores (bug do original).
class ContributionPlan {
  final int fromKey;
  final PlanMode mode;

  /// fixed: centavos. percent: centésimos de % (1250 = 12,5%).
  final int amount;
  const ContributionPlan(this.fromKey, this.mode, this.amount);

  Map<String, dynamic> toJson() => {
    'fromKey': fromKey,
    'mode': mode.name,
    'amount': amount,
  };
  factory ContributionPlan.fromJson(Map<String, dynamic> j) => ContributionPlan(
    (j['fromKey'] as num).toInt(),
    j['mode'] == 'percent' ? PlanMode.percent : PlanMode.fixed,
    (j['amount'] as num).toInt(),
  );
}

enum MovementType {
  /// Dinheiro extra que entra na caixinha, saindo do saldo livre do ciclo.
  deposit,

  /// Gasto pago com o dinheiro da caixinha (não mexe no saldo livre).
  spend,

  /// Resgate: tira da caixinha e devolve ao saldo livre do ciclo.
  redeem,
}

class Movement {
  final String id;
  String name;
  Cents cents;
  MovementType type;
  DateTime date;
  Recurrence recurrence;
  DateTime? endDate;

  Movement({
    String? id,
    required this.name,
    required this.cents,
    required this.type,
    required this.date,
    this.recurrence = Recurrence.once,
    this.endDate,
  }) : id = id ?? newId();

  /// Efeito no saldo da caixinha.
  int get sign => type == MovementType.deposit ? 1 : -1;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cents': cents,
    'type': type.name,
    'date': _iso(date),
    'recurrence': recurrence.name,
    'endDate': _iso(endDate),
  };

  factory Movement.fromJson(Map<String, dynamic> j) => Movement(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    cents: (j['cents'] as num?)?.toInt() ?? 0,
    type: MovementType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => MovementType.deposit,
    ),
    date: _date(j['date']) ?? DateTime.now(),
    recurrence: j['recurrence'] == 'monthly'
        ? Recurrence.monthly
        : Recurrence.once,
    endDate: _date(j['endDate']),
  );
}

const boxIcons = <String, IconData>{
  'piggy': LucideIcons.piggyBank,
  'home': LucideIcons.house,
  'plane': LucideIcons.plane,
  'car': LucideIcons.car,
  'food': LucideIcons.utensils,
  'shirt': LucideIcons.shirt,
  'heart': LucideIcons.heartPulse,
  'bag': LucideIcons.shoppingBag,
  'school': LucideIcons.graduationCap,
  'ticket': LucideIcons.ticket,
  'gym': LucideIcons.dumbbell,
  'game': LucideIcons.gamepad2,
  'phone': LucideIcons.smartphone,
  'tv': LucideIcons.tv,
  'pet': LucideIcons.pawPrint,
  'baby': LucideIcons.baby,
  'work': LucideIcons.briefcase,
  'gift': LucideIcons.gift,
  'target': LucideIcons.target,
  'sparkles': LucideIcons.sparkles,
};

/// Cores de fundo das caixinhas: tom 900 de cada família do Figma, mais dois
/// fundos neutros (grafite e tinta) para quem prefere algo sóbrio. Texto e
/// ícones sobre elas vêm de AppColors.softOn, então o contraste é sempre ≥ 4.5.
const boxColors = <Color>[
  Color(0xFF144A54), // teal
  Color(0xFF154961), // cyan
  Color(0xFF00336B), // blue
  Color(0xFF25245A), // indigo
  Color(0xFF4A225D), // purple
  Color(0xFF6B1428), // pink
  Color(0xFF6B1914), // red
  Color(0xFF6B3F00), // orange
  Color(0xFF6B5600), // yellow
  Color(0xFF165425), // green
  Color(0xFF005450), // mint
  Color(0xFF262626), // grafite
  Color(0xFF0E2835), // tinta (azul da marca)
];

class Caixinha {
  final String id;
  String name;
  String icon;
  int color; // ARGB
  Cents? goalCents;
  int createdKey; // ciclo em que passou a existir
  int? closedKey; // ciclo em que foi encerrada (saldo resgatado)
  List<ContributionPlan> plans;
  List<Movement> movements;

  Caixinha({
    String? id,
    required this.name,
    required this.icon,
    required this.color,
    required this.createdKey,
    required this.plans,
    this.goalCents,
    this.closedKey,
    List<Movement>? movements,
  }) : id = id ?? newId(),
       movements = movements ?? [];

  bool get isOpen => closedKey == null;
  IconData get iconData => boxIcons[icon] ?? LucideIcons.piggyBank;
  Color get colorValue => Color(color);

  ContributionPlan? planFor(int key) {
    ContributionPlan? found;
    for (final p in plans) {
      if (p.fromKey <= key && (found == null || p.fromKey >= found.fromKey))
        found = p;
    }
    return found;
  }

  ContributionPlan get currentPlan =>
      plans.reduce((a, b) => a.fromKey >= b.fromKey ? a : b);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'goalCents': goalCents,
    'createdKey': createdKey,
    'closedKey': closedKey,
    'plans': plans.map((p) => p.toJson()).toList(),
    'movements': movements.map((m) => m.toJson()).toList(),
  };

  factory Caixinha.fromJson(Map<String, dynamic> j) => Caixinha(
    id: j['id'] as String?,
    name: j['name'] as String? ?? 'Caixinha',
    icon: j['icon'] as String? ?? 'piggy',
    color: (j['color'] as num?)?.toInt() ?? boxColors.first.toARGB32(),
    goalCents: (j['goalCents'] as num?)?.toInt(),
    createdKey: (j['createdKey'] as num).toInt(),
    closedKey: (j['closedKey'] as num?)?.toInt(),
    plans: ((j['plans'] as List?) ?? [])
        .map((e) => ContributionPlan.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    movements: ((j['movements'] as List?) ?? [])
        .map((e) => Movement.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

// ── Cartão ──────────────────────────────────────────────────

const cardColors = <Color>[
  Color(0xFF8A0FD6),
  Color(0xFFFF7A00),
  Color(0xFF171717),
  Color(0xFF0062CC),
  Color(0xFF1E6F7D),
  Color(0xFFB82A22),
];

enum CardBrand { mastercard, visa, elo, other }

class PayCard {
  final String id;
  String name;
  String last4;
  int color;
  CardBrand brand;

  PayCard({
    String? id,
    required this.name,
    required this.last4,
    required this.color,
    this.brand = CardBrand.other,
  }) : id = id ?? newId();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'last4': last4,
    'color': color,
    'brand': brand.name,
  };
  factory PayCard.fromJson(Map<String, dynamic> j) => PayCard(
    id: j['id'] as String?,
    name: j['name'] as String? ?? 'Cartão',
    last4: j['last4'] as String? ?? '',
    color: (j['color'] as num?)?.toInt() ?? cardColors.first.toARGB32(),
    brand: CardBrand.values.firstWhere(
      (b) => b.name == j['brand'],
      orElse: () => CardBrand.other,
    ),
  );
}

// ── Salário ─────────────────────────────────────────────────

/// Salário com vigência: mudar o salário hoje não altera os ciclos passados.
class SalaryEntry {
  final int fromKey;
  final Cents cents;
  const SalaryEntry(this.fromKey, this.cents);
  Map<String, dynamic> toJson() => {'fromKey': fromKey, 'cents': cents};
  factory SalaryEntry.fromJson(Map<String, dynamic> j) =>
      SalaryEntry((j['fromKey'] as num).toInt(), (j['cents'] as num).toInt());
}

enum ThemePref { auto, light, dark }

// ── Raiz ────────────────────────────────────────────────────

class AppData {
  String userName;
  String? avatarPath;
  int userSince;
  int cycleStartDay;
  ThemePref theme;
  int? accentColor;
  bool hideValues;
  bool onboardingDone;
  List<SalaryEntry> salaries;
  List<Expense> expenses;
  List<Caixinha> boxes;
  List<PayCard> cards;

  /// Largura escolhida para cada card da Carteira (1 ou 2 blocos).
  Map<String, int> cardSpans;

  /// Ordem personalizada dos widgets da Carteira.
  List<String> widgetOrder;

  /// IDs dos widgets ocultados pelo usuário na Carteira.
  List<String> hiddenWidgets;

  /// Última alteração local (UTC), usada para sincronização com o Google Drive.
  DateTime? updatedAt;

  AppData({
    this.userName = '',
    this.avatarPath,
    int? userSince,
    this.cycleStartDay = 1,
    this.theme = ThemePref.auto,
    this.accentColor,
    this.hideValues = false,
    this.onboardingDone = false,
    List<SalaryEntry>? salaries,
    List<Expense>? expenses,
    List<Caixinha>? boxes,
    List<PayCard>? cards,
    Map<String, int>? cardSpans,
    List<String>? widgetOrder,
    List<String>? hiddenWidgets,
    this.updatedAt,
  }) : cardSpans = cardSpans ?? {},
       widgetOrder = widgetOrder ?? [],
       hiddenWidgets = hiddenWidgets ?? [],
       userSince = userSince ?? DateTime.now().year,
       salaries = salaries ?? [],
       expenses = expenses ?? [],
       boxes = boxes ?? [],
       cards = cards ?? [];

  static const schemaVersion = 1;

  Map<String, dynamic> toJson() => {
    'mareVersion': schemaVersion,
    'updatedAt': _iso(updatedAt?.toUtc()),
    'userName': userName,
    'avatarPath': avatarPath,
    'userSince': userSince,
    'cycleStartDay': cycleStartDay,
    'theme': theme.name,
    'accentColor': accentColor,
    'hideValues': hideValues,
    'onboardingDone': onboardingDone,
    'salaries': salaries.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'boxes': boxes.map((e) => e.toJson()).toList(),
    'cards': cards.map((e) => e.toJson()).toList(),
    'cardSpans': cardSpans,
    'widgetOrder': widgetOrder,
    'hiddenWidgets': hiddenWidgets,
  };

  factory AppData.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? [])
            .map((e) => f(Map<String, dynamic>.from(e as Map)))
            .toList();
    return AppData(
      userName: j['userName'] as String? ?? '',
      avatarPath: j['avatarPath'] as String?,
      userSince: (j['userSince'] as num?)?.toInt(),
      cycleStartDay: ((j['cycleStartDay'] as num?)?.toInt() ?? 1).clamp(1, 31),
      theme: ThemePref.values.firstWhere(
        (t) => t.name == j['theme'],
        orElse: () => ThemePref.auto,
      ),
      accentColor: (j['accentColor'] as num?)?.toInt(),
      hideValues: j['hideValues'] == true,
      onboardingDone: j['onboardingDone'] == true,
      salaries: list('salaries', SalaryEntry.fromJson),
      expenses: list('expenses', Expense.fromJson),
      boxes: list('boxes', Caixinha.fromJson),
      cards: list('cards', PayCard.fromJson),
      cardSpans:
          (j['cardSpans'] as Map?)?.map(
            (k, v) => MapEntry('$k', (v as num).toInt().clamp(1, 2)),
          ) ??
          {},
      widgetOrder: ((j['widgetOrder'] as List?) ?? [])
          .map((e) => '$e')
          .toList(),
      hiddenWidgets: ((j['hiddenWidgets'] as List?) ?? [])
          .map((e) => '$e')
          .toList(),
      updatedAt: _date(j['updatedAt'])?.toUtc(),
    );
  }

  /// Importa o backup / localStorage do app web antigo (finapp_v3).
  ///
  /// Conversões: reais (float) → centavos; 'until' → recorrente com data
  /// final; extras sem data → depósito no ciclo de criação da caixinha;
  /// dívidas → gastos pagos com a caixinha.
  factory AppData.fromLegacy(
    Map<String, dynamic> raw, {
    required int Function(DateTime) keyOf,
  }) {
    final d = raw['data'] is Map ? Map<String, dynamic>.from(raw['data']) : raw;
    final now = DateTime.now();
    final nowKey = keyOf(now);
    DateTime ts(dynamic v) =>
        v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : now;
    DateTime? until(dynamic v) => v is String ? DateTime.tryParse(v) : null;

    final expenses = <Expense>[];
    for (final e in (d['expenses'] as List? ?? [])) {
      if (e is! Map) continue;
      final legacyRecurring =
          e['recurrence'] == null &&
          e['createdAt'] == null; // itens antigos valiam sempre
      final rec = legacyRecurring ? Recurrence.monthly : _rec(e['recurrence']);
      final created = ts(e['createdAt'] ?? e['id']);
      expenses.add(
        Expense(
          name: '${e['name'] ?? ''}',
          cents: centsFromLegacy(e['value']),
          categoryId: categoryById(e['category'] as String?).id,
          date: created,
          recurrence: rec,
          endDate: e['recurrence'] == 'until' ? until(e['untilDate']) : null,
          createdAt: created,
        ),
      );
    }

    final boxes = <Caixinha>[];
    var colorIdx = 0;
    for (final b in (d['caixinhas'] as List? ?? [])) {
      if (b is! Map) continue;
      final created = b['id'] is num ? keyOf(ts(b['id'])) : nowKey;
      final percent = b['mode'] == 'percent';
      final amount = percent
          ? ((b['amount'] as num? ?? 0) * 100).round()
          : centsFromLegacy(b['amount']);
      final moves = <Movement>[];
      for (final x in (b['extras'] as List? ?? [])) {
        if (x is! Map) continue;
        moves.add(
          Movement(
            name: '${x['name'] ?? 'Extra'}',
            cents: centsFromLegacy(x['value']),
            type: MovementType.deposit,
            date: ts(x['id']),
          ),
        );
      }
      for (final x in (b['debts'] as List? ?? [])) {
        if (x is! Map) continue;
        final legacy = x['recurrence'] == null && x['createdAt'] == null;
        moves.add(
          Movement(
            name: '${x['name'] ?? 'Gasto'}',
            cents: centsFromLegacy(x['value']),
            type: MovementType.spend,
            date: ts(x['createdAt'] ?? x['id']),
            recurrence: legacy ? Recurrence.monthly : _rec(x['recurrence']),
            endDate: x['recurrence'] == 'until' ? until(x['untilDate']) : null,
          ),
        );
      }
      boxes.add(
        Caixinha(
          name: '${b['name'] ?? 'Caixinha'}',
          icon: 'piggy',
          color: boxColors[colorIdx++ % boxColors.length].toARGB32(),
          createdKey: created,
          plans: [
            ContributionPlan(
              created,
              percent ? PlanMode.percent : PlanMode.fixed,
              amount,
            ),
          ],
          movements: moves,
        ),
      );
    }

    final salary = centsFromLegacy(d['salary'] ?? 0);
    final firstKey = [
      nowKey,
      ...expenses.map((e) => keyOf(e.date)),
      ...boxes.map((b) => b.createdKey),
    ].reduce(min);
    final name = '${d['userName'] ?? ''}';
    return AppData(
      userName: name == 'Usuário' ? '' : name,
      userSince: (d['userSince'] as num?)?.toInt(),
      cycleStartDay: ((d['monthStartDay'] as num?)?.toInt() ?? 1).clamp(1, 31),
      theme: ThemePref.values.firstWhere(
        (t) => t.name == d['themePreference'],
        orElse: () => ThemePref.auto,
      ),
      onboardingDone: true,
      salaries: salary > 0 ? [SalaryEntry(firstKey, salary)] : [],
      expenses: expenses,
      boxes: boxes,
    );
  }
}
