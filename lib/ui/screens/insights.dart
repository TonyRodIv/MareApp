import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cycle.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../widgets/charts.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'add_expense.dart';
import 'extrato.dart';
import 'shell.dart';

/// Esqueleto comum das telas de detalhe com top bar fixa + progressive blur.
class _DetailPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  const _DetailPage({required this.title, this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final pad = sidePadding(context);
    return CupertinoPageScaffold(
      backgroundColor: c.bg,
      child: Stack(
        children: [
          const GlowBackground(height: 460),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              PinnedCupertinoBar(
                height: 60,
                builder: (ctx, progress) => Row(
                  children: [
                    const BackChevron(),
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: progress > 0.35 ? 1.0 : 0.0,
                        child: Text(
                          title,
                          style: T.bodyStrong.copyWith(color: c.text),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                    Text(title, style: T.title.copyWith(color: c.text, fontSize: 28)),
                    if (subtitle != null) ...[
                      const SizedBox(height: Space.xs),
                      Text(subtitle!, style: T.label.copyWith(color: c.textSecondary)),
                    ],
                    const SizedBox(height: Space.lg),
                    ...children,
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Categorias ──────────────────────────────────────────────

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final data = f.byCategory(f.current);
    final total = data.fold<int>(0, (t, e) => t + e.value);
    final prev = f.byCategory(f.current.prev(s.data.cycleStartDay));
    final prevMap = {for (final e in prev) e.key.id: e.value};
    return _DetailPage(
      title: 'Por categoria',
      subtitle: '${f.current.label()} · ${fmtMoney(total, hidden: hidden)}',
      children: [
        if (data.isEmpty)
          EmptyState(
            icon: LucideIcons.chartPie,
            title: 'Sem gastos neste ciclo',
            action: 'Adicionar gasto',
            onAction: () => openAddExpense(context),
          )
        else ...[
          AppCard(
            child: Center(
              child: SizedBox(width: 220, child: CategoryWaffle(data: data)),
            ),
          ),
          const SizedBox(height: 12),
          for (final e in data)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  _openExtratoFiltered(context, e.key.id);
                },
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconBadge(e.key.icon, e.key.color, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.key.label, style: T.bodyStrong.copyWith(color: c.text)),
                              Text(_delta(e.value, prevMap[e.key.id], hidden), style: T.small.copyWith(color: c.textSecondary)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              fmtMoney(e.value, hidden: hidden),
                              style: T.bodyStrong.copyWith(color: c.text),
                            ),
                            Text('${(e.value / total * 100).round()}%', style: T.small.copyWith(color: c.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SpringBar(fraction: e.value / total, color: c.tone(e.key.color), track: c.cardAlt, height: 6),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _delta(int cur, int? prev, bool hidden) {
    if (prev == null || prev == 0) return 'Novo neste ciclo';
    final d = cur - prev;
    if (d == 0) return 'Igual ao ciclo anterior';
    return '${d > 0 ? '+' : '−'}${fmtMoney(d.abs(), hidden: hidden)} vs. ciclo anterior';
  }

  void _openExtratoFiltered(BuildContext context, String id) => shellNav.goTo(1, filter: ExtratoFilter(categoryId: id));
}

// ── Ritmo do ciclo (Para hoje / Fim de semana / Sequência) ──

class RhythmScreen extends StatelessWidget {
  const RhythmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final cy = f.current;
    final today = f.todayAllowance;
    return _DetailPage(
      title: 'Ritmo do ciclo',
      subtitle: '${f.daysLeftInclToday} ${f.daysLeftInclToday == 1 ? 'dia restante' : 'dias restantes'} em ${cy.label()}',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pode gastar hoje', style: T.label.copyWith(color: c.textSecondary)),
              CountingMoney(
                cents: today < 0 ? 0 : today,
                builder: (v) => MoneyText(v, hidden: hidden, style: T.display),
              ),
              const SizedBox(height: 6),
              Text(
                'Saldo livre de ${fmtMoney(f.freeBalance(cy), hidden: hidden)} dividido pelos dias que faltam. Se gastar menos hoje, sobra mais para amanhã.',
                style: T.small.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          title: 'Calendário do ciclo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CycleGrid(f: f, columns: 7),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _legend(context, c.isDark ? Palette.teal100 : Palette.teal200, 'Sem gastos'),
                  _legend(context, c.isDark ? Palette.teal550 : Palette.teal750, 'Dentro da meta'),
                  _legend(context, c.isDark ? const Color(0xFF5B8087) : Palette.neutral400, 'Passou da meta'),
                  _legend(context, c.accentWarm, 'Hoje'),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Meta diária deste ciclo: ${fmtMoney(f.idealDaily(cy), hidden: hidden)}',
                style: T.small.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          titleWidget: Row(
            children: [
              Icon(LucideIcons.zap, color: c.accentWarm),
              const SizedBox(width: 8),
              Text('${f.streak} ${f.streak == 1 ? 'dia' : 'dias'} de sequência', style: T.headline.copyWith(color: c.text)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeekStreak(f: f),
              const SizedBox(height: 12),
              Text(
                'Cada dia em que seus gastos do dia a dia ficam dentro da meta diária conta para a sequência. Gastos recorrentes não entram.',
                style: T.small.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          title: 'Resumo',
          child: Column(
            children: [
              _line(context, 'Salário', f.salaryFor(cy), hidden),
              _line(context, 'Gastos recorrentes', -f.fixedTotal(cy), hidden),
              _line(context, 'Aportes nas caixinhas', -f.contributionsTotal(cy), hidden),
              _line(context, 'Gastos do dia a dia', -f.variableTotal(cy), hidden),
              if (f.committed(cy) - f.fixedTotal(cy) - f.contributionsTotal(cy) != 0)
                _line(context, 'Extras e resgates de caixinhas', -(f.committed(cy) - f.fixedTotal(cy) - f.contributionsTotal(cy)), hidden),
              Container(height: 1, color: c.border, margin: const EdgeInsets.symmetric(vertical: 8)),
              _line(context, 'Saldo livre', f.freeBalance(cy), hidden, strong: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 6),
      Text(label, style: T.small.copyWith(color: context.c.textSecondary)),
    ],
  );

  Widget _line(BuildContext context, String label, int v, bool hidden, {bool strong = false}) {
    final c = context.c;
    final st = (strong ? T.bodyStrong : T.label).copyWith(color: strong ? c.text : c.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: st)),
          Text(
            fmtMoney(v, hidden: hidden),
            style: st.copyWith(color: v < 0 && strong ? c.negative : (strong ? c.text : c.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── Assinaturas ─────────────────────────────────────────────

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final subs = f.subscriptions(f.current);
    final total = subs.fold<int>(0, (t, e) => t + e.cents);
    return _DetailPage(
      title: 'Assinaturas',
      subtitle: subs.isEmpty ? null : '${fmtMoney(total, hidden: hidden)} por mês · ${fmtMoney(total * 12, hidden: hidden)} por ano',
      children: [
        if (subs.isEmpty)
          EmptyState(
            icon: LucideIcons.tv,
            title: 'Nenhuma assinatura',
            message: 'Adicione um gasto recorrente na categoria Assinaturas para acompanhar quanto seus serviços custam.',
            action: 'Adicionar',
            onAction: () => openAddExpense(context),
          )
        else ...[
          AppCard(
            child: SubscriptionBubbles(subs: subs, hidden: hidden),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(Space.radiusCard)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [for (final e in subs) ExpenseRow(e: e, f: f, hidden: hidden)],
            ),
          ),
          const SizedBox(height: 10),
          Text('Toque numa assinatura para editar ou parar de repetir.', style: T.small.copyWith(color: c.textTertiary)),
        ],
      ],
    );
  }
}

// ── Histórico ───────────────────────────────────────────────

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = context.store;
    final f = s.f;
    final hidden = s.data.hideValues;
    final cycles = f.lastCycles(12).reversed.toList();
    return _DetailPage(
      title: 'Histórico',
      subtitle: 'Calculado a partir dos seus lançamentos',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HistoryBars(f: f, cycles: isWide(context) ? 12 : 6, height: 180, hidden: hidden),
              const SizedBox(height: 8),
              Row(
                children: [
                  _dot(c.isDark ? Palette.teal550 : Palette.teal750),
                  Text(' Fixos e caixinhas   ', style: T.small.copyWith(color: c.textSecondary)),
                  _dot(c.isDark ? Palette.teal100 : Palette.teal200),
                  Text(' Dia a dia', style: T.small.copyWith(color: c.textSecondary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final cy in cycles)
          if (f.salaryFor(cy) > 0 || f.expensesTotal(cy) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cy.label(), style: T.bodyStrong.copyWith(color: c.text)),
                          Text(
                            'Gastos ${fmtMoney(f.expensesTotal(cy), hidden: hidden)} · Guardado ${fmtMoney(f.contributionsTotal(cy), hidden: hidden)}',
                            style: T.small.copyWith(color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmtMoney(f.freeBalance(cy), hidden: hidden),
                          style: T.bodyStrong.copyWith(color: f.freeBalance(cy) < 0 ? c.negative : c.positive),
                        ),
                        Text(
                          sameDay(cy.start, f.current.start) ? 'livre até agora' : 'sobrou',
                          style: T.tiny.copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _dot(Color c) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
  );
}
