import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/validation.dart';
import '../widgets/kit.dart';
import 'cards.dart';

enum AiImportMode { expenses, full }

/// Resultado validado da leitura de um texto gerado por agente de IA.
class AiImportPreview {
  final AiImportMode mode;
  final int? salaryCents;
  final int? cycleStartDay;
  final List<PayCard> cards;
  final List<Caixinha> boxes;
  final List<Expense> expenses;
  final int skippedCount;

  const AiImportPreview({
    required this.mode,
    this.salaryCents,
    this.cycleStartDay,
    this.cards = const [],
    this.boxes = const [],
    this.expenses = const [],
    this.skippedCount = 0,
  });

  int get totalExpensesCents =>
      expenses.fold<int>(0, (t, e) => t + e.cents);

  bool get isEmpty =>
      salaryCents == null &&
      cycleStartDay == null &&
      cards.isEmpty &&
      boxes.isEmpty &&
      expenses.isEmpty;
}

/// Faz o parsing tolerante de texto/JSON gerado por ChatGPT, Claude ou Gemini.
/// Remove blocos markdown (` ```json `), aceita valores em reais ou centavos,
/// datas `YYYY-MM-DD` ou `DD/MM/YYYY`, categorias por ID ou nome e contas por nome.
(AiImportPreview?, String?) parseAiImport(
  String raw, {
  required List<PayCard> existingCards,
  required int currentCycleKey,
  AiImportMode expectedMode = AiImportMode.full,
}) {
  final cleaned = _extractJsonPayload(raw);
  if (cleaned == null) {
    return (
      null,
      'Não encontrei um bloco JSON válido no texto colado. Copie a resposta completa do agente de IA.',
    );
  }

  final dynamic decoded;
  try {
    decoded = jsonDecode(cleaned);
  } catch (_) {
    return (
      null,
      'O JSON colado parece incompleto ou mal formatado. Peça para a IA gerar apenas o bloco JSON.',
    );
  }

  List<dynamic> rawExpenses = const [];
  List<dynamic> rawCards = const [];
  List<dynamic> rawBoxes = const [];
  int? salaryCents;
  int? cycleStartDay;
  var detectedMode = expectedMode;

  if (decoded is List) {
    rawExpenses = decoded;
    detectedMode = AiImportMode.expenses;
  } else if (decoded is Map) {
    final map = Map<String, dynamic>.from(decoded);
    final tag = '${map['mareImport'] ?? map['type'] ?? ''}'.toLowerCase();
    if (tag == 'full' ||
        map.containsKey('salary') ||
        map.containsKey('salaries') ||
        map.containsKey('boxes') ||
        map.containsKey('cards')) {
      detectedMode = AiImportMode.full;
    }
    if (map['salary'] != null) {
      final sal = _parseCents(map['salary']);
      if (sal != null && sal > 0) salaryCents = sal;
    } else if (map['salaries'] is List && (map['salaries'] as List).isNotEmpty) {
      final lastSal = (map['salaries'] as List).last;
      if (lastSal is Map && lastSal['cents'] is num) {
        salaryCents = (lastSal['cents'] as num).toInt();
      }
    }
    if (map['cycleStartDay'] is num) {
      cycleStartDay = (map['cycleStartDay'] as num).toInt().clamp(1, 31);
    }
    if (map['cards'] is List) rawCards = map['cards'] as List;
    if (map['boxes'] is List) rawBoxes = map['boxes'] as List;
    if (map['expenses'] is List) {
      rawExpenses = map['expenses'] as List;
    } else if (map['gastos'] is List) {
      rawExpenses = map['gastos'] as List;
    }
  } else {
    return (null, 'Formato não reconhecido. Use as instruções acima.');
  }

  // Mapa de contas/cartões (existentes + novos declarados no JSON)
  final cardsByKey = <String, PayCard>{
    for (final k in existingCards) foldText(k.name): k,
    for (final k in existingCards) k.id: k,
  };
  final newCards = <PayCard>[];

  for (final item in rawCards) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final name = '${m['name'] ?? m['nome'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    final key = foldText(name);
    final explicitId = m['id'] is String ? '${m['id']}' : null;
    if (cardsByKey.containsKey(key)) {
      if (explicitId != null) cardsByKey[explicitId] = cardsByKey[key]!;
      continue;
    }
    final isCard = m['isCard'] == true ||
        '${m['type'] ?? m['tipo'] ?? ''}'.toLowerCase().contains('cart') ||
        '${m['last4'] ?? ''}'.trim().isNotEmpty;
    final brand = _parseBrand('${m['brand'] ?? m['bandeira'] ?? ''}');
    final card = PayCard(
      id: explicitId,
      name: name,
      last4: '${m['last4'] ?? ''}'.trim(),
      color: m['color'] is num
          ? (m['color'] as num).toInt()
          : bankColorFor(name).toARGB32(),
      brand: isCard ? brand : CardBrand.other,
      isCard: isCard,
    );
    cardsByKey[key] = card;
    cardsByKey[card.id] = card;
    newCards.add(card);
  }

  // Caixinhas
  final newBoxes = <Caixinha>[];
  var colorIdx = 0;
  for (final item in rawBoxes) {
    if (item is! Map) continue;
    final m = Map<String, dynamic>.from(item);
    final name = '${m['name'] ?? m['nome'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    if (m['plans'] is List && (m['plans'] as List).isNotEmpty) {
      newBoxes.add(Caixinha.fromJson(m));
      continue;
    }
    final isPercent = '${m['mode'] ?? m['modo'] ?? ''}'.toLowerCase().contains(
      'percent',
    );
    final rawAmt = m['amount'] ?? m['valor'] ?? m['aporte'];
    final amount = isPercent
        ? ((_parseDouble(rawAmt) ?? 10) * 100).round().clamp(100, 10000)
        : (_parseCents(rawAmt) ?? 10000).clamp(1, MoneyLimits.maxCents);
    final goal = m['goalCents'] is num
        ? (m['goalCents'] as num).toInt()
        : (m['goal'] != null || m['meta'] != null
              ? _parseCents(m['goal'] ?? m['meta'])
              : null);
    newBoxes.add(
      Caixinha(
        name: name,
        icon: boxIcons.containsKey(m['icon']) ? '${m['icon']}' : 'piggy',
        color: m['color'] is num
            ? (m['color'] as num).toInt()
            : boxColors[colorIdx++ % boxColors.length].toARGB32(),
        goalCents: goal != null && goal > 0 ? goal : null,
        createdKey: m['createdKey'] is num
            ? (m['createdKey'] as num).toInt()
            : currentCycleKey,
        plans: [
          ContributionPlan(
            currentCycleKey,
            isPercent ? PlanMode.percent : PlanMode.fixed,
            amount,
          ),
        ],
      ),
    );
  }

  // Gastos
  final parsedExpenses = <Expense>[];
  var skipped = 0;
  for (final item in rawExpenses) {
    if (item is! Map) {
      skipped++;
      continue;
    }
    final m = Map<String, dynamic>.from(item);
    final name = '${m['name'] ?? m['nome'] ?? m['descricao'] ?? ''}'.trim();
    final cents = m['cents'] is num
        ? (m['cents'] as num).round()
        : _parseCents(m['value'] ?? m['valor'] ?? m['amount']);
    if (name.isEmpty || cents == null || cents <= 0) {
      skipped++;
      continue;
    }
    final catId = _resolveCategoryId(
      '${m['categoryId'] ?? m['category'] ?? m['categoria'] ?? ''}',
      fallbackName: name,
    );
    final date =
        _parseDate(m['date'] ?? m['data']) ?? DateTime.now();
    final recRaw = '${m['recurrence'] ?? m['recorrencia'] ?? 'once'}'
        .toLowerCase();
    final rec = (recRaw.contains('month') ||
            recRaw.contains('mens') ||
            recRaw.contains('recor'))
        ? Recurrence.monthly
        : Recurrence.once;
    final endDate = _parseDate(m['endDate'] ?? m['ate']);

    String? cardId;
    final cardRaw =
        '${m['cardId'] ?? m['card'] ?? m['cartao'] ?? m['conta'] ?? ''}'.trim();
    if (cardRaw.isNotEmpty) {
      final matched = cardsByKey[cardRaw] ?? cardsByKey[foldText(cardRaw)];
      if (matched != null) {
        cardId = matched.id;
      } else {
        final created = PayCard(
          name: cardRaw,
          color: bankColorFor(cardRaw).toARGB32(),
        );
        cardsByKey[foldText(cardRaw)] = created;
        cardsByKey[created.id] = created;
        newCards.add(created);
        cardId = created.id;
      }
    }

    parsedExpenses.add(
      Expense(
        name: name,
        cents: cents.clamp(1, MoneyLimits.maxCents),
        categoryId: catId,
        cardId: cardId,
        date: date,
        recurrence: rec,
        endDate: rec == Recurrence.monthly ? endDate : null,
      ),
    );
  }

  final preview = AiImportPreview(
    mode: detectedMode,
    salaryCents: salaryCents,
    cycleStartDay: cycleStartDay,
    cards: newCards,
    boxes: newBoxes,
    expenses: parsedExpenses,
    skippedCount: skipped,
  );
  if (preview.isEmpty) {
    return (null, 'Nenhum dado válido encontrado no JSON colado.');
  }
  return (preview, null);
}

String? _extractJsonPayload(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
  final m = fence.firstMatch(trimmed);
  final body = (m != null ? m.group(1) ?? '' : trimmed).trim();
  final objStart = body.indexOf('{');
  final arrStart = body.indexOf('[');
  int start = -1;
  String close = '}';
  if (objStart >= 0 && (arrStart < 0 || objStart < arrStart)) {
    start = objStart;
    close = '}';
  } else if (arrStart >= 0) {
    start = arrStart;
    close = ']';
  }
  if (start < 0) return null;
  final end = body.lastIndexOf(close);
  if (end <= start) return null;
  return body.substring(start, end + 1);
}

double? _parseDouble(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw is! String) return null;
  var s = raw.trim().replaceAll(RegExp(r'[R$\s]'), '');
  if (s.contains(',') && s.contains('.')) {
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (s.contains(',')) {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}

int? _parseCents(dynamic raw) {
  final d = _parseDouble(raw);
  if (d == null || !d.isFinite) return null;
  return (d.abs() * 100).round();
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final s = '$raw'.trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  final br = RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?$').firstMatch(s);
  if (br != null) {
    final day = int.parse(br.group(1)!);
    final month = int.parse(br.group(2)!);
    final yrRaw = br.group(3);
    final year = yrRaw == null
        ? DateTime.now().year
        : (yrRaw.length == 2 ? 2000 + int.parse(yrRaw) : int.parse(yrRaw));
    return DateTime(year, month.clamp(1, 12), day.clamp(1, 31));
  }
  return null;
}

String _resolveCategoryId(String raw, {required String fallbackName}) {
  final q = foldText(raw);
  if (q.isNotEmpty) {
    for (final cat in categories) {
      if (cat.id == q || foldText(cat.label) == q) return cat.id;
    }
    for (final cat in categories) {
      if (foldText(cat.label).contains(q) || q.contains(cat.id)) return cat.id;
    }
  }
  return guessCategory(fallbackName)?.id ?? 'outros';
}

CardBrand _parseBrand(String raw) {
  final q = foldText(raw);
  if (q.contains('master')) return CardBrand.mastercard;
  if (q.contains('visa')) return CardBrand.visa;
  if (q.contains('elo')) return CardBrand.elo;
  return CardBrand.other;
}

/// Tela unificada de importação com IA: aceita tanto gastos avulsos/faturas
/// quanto dados completos (salário, ciclo, contas, caixinhas e gastos) e
/// pergunta ao importar se o usuário quer adicionar aos dados atuais ou substituir.
class AiImportScreen extends StatefulWidget {
  final AiImportMode initialMode;
  const AiImportScreen({super.key, this.initialMode = AiImportMode.full});

  @override
  State<AiImportScreen> createState() => _AiImportScreenState();
}

class _AiImportScreenState extends State<AiImportScreen> {
  final _input = TextEditingController();
  AiImportPreview? _preview;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _promptFor(Store s) {
    final cats = categories.map((e) => e.id).join(', ');
    final cards = s.data.cards.isEmpty
        ? 'Nubank, Inter, Itaú (use o nome do banco se houver)'
        : s.data.cards.map((c) => c.name).join(', ');
    final today = DateTime.now();
    final todayIso =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return '''
Converta os dados financeiros que vou te enviar (fatura, extrato, lista de gastos, planilha ou anotações) em um único bloco JSON pronto para importar no app maré.

Regras obrigatórias:
- Responda APENAS com um bloco de código ```json válido, sem texto extra antes ou depois.
- Inclua apenas as seções que existirem no que eu enviar ("expenses" para gastos; "salary", "cycleStartDay", "cards" e "boxes" são opcionais).
- Todos os valores monetários ("salary", "value", "amount", "goal") devem estar em reais com ponto decimal (ex.: 184.50), sempre positivos.
- Em "expenses", use "date" no formato YYYY-MM-DD (se não houver data, use "$todayIso"), "recurrence": "once" (único) ou "monthly" (assinatura/recorrente), "category" estritamente entre [$cats] e "card" (opcional: $cards).
- Em "cards" (opcional), use "isCard": true para cartão ("brand": "mastercard" | "visa" | "elo" | "other") ou false para conta bancária.
- Em "boxes" (opcional), use "mode": "fixed" (reais) ou "percent" (% do salário).

Formato esperado:
```json
{
  "salary": 3200.00,
  "cycleStartDay": 5,
  "cards": [
    { "name": "Nubank", "isCard": true, "brand": "mastercard" }
  ],
  "boxes": [
    { "name": "Reserva", "mode": "fixed", "amount": 300.00, "goal": 6000.00 }
  ],
  "expenses": [
    {
      "name": "Supermercado",
      "value": 184.50,
      "category": "alimentacao",
      "date": "$todayIso",
      "recurrence": "once",
      "card": "Nubank"
    }
  ]
}
```
'''.trim();
  }

  void _analyze(String text) {
    if (text.trim().isEmpty) {
      setState(() {
        _preview = null;
        _error = null;
      });
      return;
    }
    final s = context.storeRead;
    final (preview, err) = parseAiImport(
      text,
      existingCards: s.data.cards,
      currentCycleKey: s.cycle.key,
    );
    setState(() {
      _preview = preview;
      _error = err;
    });
  }

  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text ?? '';
    if (text.trim().isEmpty) {
      if (mounted) {
        toast(
          context,
          'Nada copiado na área de transferência',
          icon: LucideIcons.clipboardX,
        );
      }
      return;
    }
    _input.text = text;
    _analyze(text);
  }

  Future<void> _copyPrompt(Store s) async {
    await Clipboard.setData(ClipboardData(text: _promptFor(s)));
    HapticFeedback.lightImpact();
    if (mounted) {
      toast(context, 'Instruções copiadas — cole no ChatGPT, Claude ou Gemini');
    }
  }

  Future<void> _applyImport() async {
    var p = _preview;
    if (p == null) return;
    final s = context.storeRead;
    final hasExistingData =
        s.data.expenses.isNotEmpty ||
        s.data.boxes.isNotEmpty ||
        s.data.cards.isNotEmpty ||
        s.data.salaries.isNotEmpty;

    var replaceExisting = false;
    if (hasExistingData) {
      final choice = await actionSheet<bool>(
        context,
        title: 'Como deseja importar?',
        message:
            'Você pode adicionar estes itens aos seus dados atuais ou substituir tudo o que está salvo.',
        actions: const [
          SheetAction(
            'Adicionar aos dados atuais',
            false,
            icon: LucideIcons.circlePlus,
          ),
          SheetAction(
            'Substituir dados atuais',
            true,
            destructive: true,
            icon: LucideIcons.refreshCw,
          ),
        ],
      );
      if (choice == null || !mounted) return;
      replaceExisting = choice;
    }

    if (replaceExisting) {
      // Re-faz o parsing sem cartões existentes para preservar todos os vínculos.
      final (fresh, err) = parseAiImport(
        _input.text,
        existingCards: const [],
        currentCycleKey: s.cycle.key,
      );
      if (fresh == null) {
        toast(
          context,
          err ?? 'Não foi possível preparar a importação',
          icon: LucideIcons.triangleAlert,
        );
        return;
      }
      p = fresh;
      s.data.expenses.clear();
      s.data.boxes.clear();
      s.data.cards.clear();
      if (p.salaryCents != null) s.data.salaries.clear();
    }

    if (p.cycleStartDay != null) {
      s.setCycleStartDay(p.cycleStartDay!);
    }
    if (p.salaryCents != null) {
      s.setSalary(p.salaryCents!);
    }
    for (final k in p.cards) {
      s.saveCard(k);
    }
    for (final b in p.boxes) {
      if (b.movements.isNotEmpty || b.plans.length > 1) {
        s.data.boxes.add(b);
      } else {
        final plan = b.currentPlan;
        s.addBox(
          name: b.name,
          icon: b.icon,
          color: b.color,
          mode: plan.mode,
          amount: plan.amount,
          goal: b.goalCents,
        );
      }
    }
    var added = 0;
    for (final e in p.expenses) {
      final err = s.addExpense(e);
      if (err == null) added++;
    }

    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.pop(context);
    final parts = <String>[
      if (added > 0) '$added ${added == 1 ? 'gasto' : 'gastos'}',
      if (p.cards.isNotEmpty)
        '${p.cards.length} ${p.cards.length == 1 ? 'conta' : 'contas'}',
      if (p.boxes.isNotEmpty)
        '${p.boxes.length} ${p.boxes.length == 1 ? 'caixinha' : 'caixinhas'}',
    ];
    toast(
      context,
      parts.isEmpty ? 'Dados importados!' : 'Importado: ${parts.join(', ')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final pad = sidePadding(context, maxWidth: 640);
    final (btnBg, btnFg) = softActionTone(
      c.palette.primary[500],
      isDark: c.isDark,
    );

    return SheetScaler(
      child: CupertinoPageScaffold(
        backgroundColor: c.bg,
        child: Stack(
          children: [
            const GlowBackground(height: 440),
            CollapsingTitleScope(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  PinnedCupertinoBar(
                    height: 60,
                    maxWidth: 640,
                    builder: (ctx, progress) => Row(
                      children: [
                        const BackChevron(),
                        Expanded(
                          child: BarTitle(
                            'Importar com IA',
                            progress: progress,
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, Space.sm, pad, Space.xl),
                    sliver: SliverList.list(
                      children: [
                        LargeTitle('Importar com IA', style: T.pageTitle),
                        const SizedBox(height: Space.base),

                        // Passo 1: Copiar instruções para o agente de IA
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconBadge(
                                    LucideIcons.sparkles,
                                    c.primary,
                                    size: 40,
                                  ),
                                  const SizedBox(width: Space.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '1. Envie as instruções à IA',
                                          style: T.bodyStrong.copyWith(
                                            color: c.text,
                                          ),
                                        ),
                                        Text(
                                          'Cole o prompt no ChatGPT, Claude ou Gemini junto com sua fatura, extrato, planilha ou anotações',
                                          style: T.small.copyWith(
                                            color: c.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Space.md),
                              PillButton(
                                'Copiar instruções para IA',
                                icon: LucideIcons.copy,
                                background: btnBg,
                                foreground: btnFg,
                                height: 48,
                                onTap: () => _copyPrompt(s),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.md),

                        // Passo 2: Colar o JSON gerado pela IA
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '2. Cole a resposta da IA',
                                      style: T.bodyStrong.copyWith(
                                        color: c.text,
                                      ),
                                    ),
                                  ),
                                  Pressable(
                                    onTap: _paste,
                                    child: Tag(
                                      'Colar',
                                      icon: LucideIcons.clipboardPaste,
                                      bg: c.cardAlt,
                                      fg: c.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Space.md),
                              AppField(
                                controller: _input,
                                bg: c.isDark ? c.bg : c.surfaceLow,
                                placeholder: 'Cole aqui o bloco JSON gerado…',
                                minLines: 5,
                                maxLines: 10,
                                onChanged: _analyze,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: Space.sm),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      LucideIcons.triangleAlert,
                                      size: 16,
                                      color: c.negative,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: T.small.copyWith(
                                          color: c.negative,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Prévia pronta para importar
                        if (_preview != null) ...[
                          const SizedBox(height: Space.md),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      LucideIcons.circleCheck,
                                      size: 18,
                                      color: c.positive,
                                    ),
                                    const SizedBox(width: Space.sm),
                                    Expanded(
                                      child: Text(
                                        'Pronto para importar',
                                        style: T.bodyStrong.copyWith(
                                          color: c.text,
                                        ),
                                      ),
                                    ),
                                    if (_preview!.expenses.isNotEmpty)
                                      Text(
                                        fmtMoney(_preview!.totalExpensesCents),
                                        style: T.bodyStrong.copyWith(
                                          color: c.primary,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: Space.sm),
                                Wrap(
                                  spacing: Space.sm,
                                  runSpacing: Space.sm,
                                  children: [
                                    if (_preview!.expenses.isNotEmpty)
                                      Tag(
                                        '${_preview!.expenses.length} ${_preview!.expenses.length == 1 ? 'gasto' : 'gastos'}',
                                        icon: LucideIcons.receipt,
                                      ),
                                    if (_preview!.cards.isNotEmpty)
                                      Tag(
                                        '${_preview!.cards.length} ${_preview!.cards.length == 1 ? 'conta' : 'contas'}',
                                        icon: LucideIcons.landmark,
                                      ),
                                    if (_preview!.boxes.isNotEmpty)
                                      Tag(
                                        '${_preview!.boxes.length} ${_preview!.boxes.length == 1 ? 'caixinha' : 'caixinhas'}',
                                        icon: LucideIcons.piggyBank,
                                      ),
                                    if (_preview!.salaryCents != null)
                                      Tag(
                                        'Salário ${fmtMoney(_preview!.salaryCents!)}',
                                        icon: LucideIcons.banknote,
                                      ),
                                    if (_preview!.cycleStartDay != null)
                                      Tag(
                                        'Dia ${_preview!.cycleStartDay}',
                                        icon: LucideIcons.calendarSync,
                                      ),
                                  ],
                                ),
                                if (_preview!.expenses.isNotEmpty) ...[
                                  const SizedBox(height: Space.md),
                                  for (final e in _preview!.expenses.take(4))
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            e.category.icon,
                                            size: 16,
                                            color: c.tone(e.category.color),
                                          ),
                                          const SizedBox(width: Space.sm),
                                          Expanded(
                                            child: Text(
                                              e.name,
                                              style: T.label.copyWith(
                                                color: c.text,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            fmtMoney(e.cents),
                                            style: T.labelStrong.copyWith(
                                              color: c.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_preview!.expenses.length > 4)
                                    Text(
                                      '+ ${_preview!.expenses.length - 4} outros gastos…',
                                      style: T.small.copyWith(
                                        color: c.textTertiary,
                                      ),
                                    ),
                                ],
                                const SizedBox(height: Space.base),
                                PillButton(
                                  'Importar dados',
                                  icon: LucideIcons.download,
                                  onTap: _applyImport,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
