import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mare/data/brands.dart';
import 'package:mare/data/drive_sync.dart';
import 'package:mare/data/models.dart';
import 'package:mare/data/validation.dart';

void main() {
  group('reconcileSync', () {
    final t0 = DateTime.utc(2026, 11, 20, 12, 0, 0);
    final t1 = DateTime.utc(2026, 11, 20, 12, 5, 0);
    final t2 = DateTime.utc(2026, 11, 20, 12, 10, 0);

    test('nada em nenhum dos lados fica em dia', () {
      expect(
        reconcileSync(
          localUpdatedAt: null,
          remoteUpdatedAt: null,
          lastSyncedAt: null,
          hasLocalData: false,
          hasRemoteData: false,
        ),
        SyncDecision.upToDate,
      );
    });

    test('só local com dados faz upload', () {
      expect(
        reconcileSync(
          localUpdatedAt: t1,
          remoteUpdatedAt: null,
          lastSyncedAt: null,
          hasLocalData: true,
          hasRemoteData: false,
        ),
        SyncDecision.upload,
      );
    });

    test('só nuvem com dados faz download', () {
      expect(
        reconcileSync(
          localUpdatedAt: null,
          remoteUpdatedAt: t1,
          lastSyncedAt: null,
          hasLocalData: false,
          hasRemoteData: true,
        ),
        SyncDecision.download,
      );
    });

    test('primeira conexão com dados nos dois lados pede decisão (conflito)', () {
      expect(
        reconcileSync(
          localUpdatedAt: t1,
          remoteUpdatedAt: t2,
          lastSyncedAt: null,
          hasLocalData: true,
          hasRemoteData: true,
        ),
        SyncDecision.conflict,
      );
    });

    test('apenas local mudou desde a última sincronização → upload', () {
      expect(
        reconcileSync(
          localUpdatedAt: t2,
          remoteUpdatedAt: t0,
          lastSyncedAt: t1,
          hasLocalData: true,
          hasRemoteData: true,
        ),
        SyncDecision.upload,
      );
    });

    test('apenas nuvem mudou desde a última sincronização → download', () {
      expect(
        reconcileSync(
          localUpdatedAt: t0,
          remoteUpdatedAt: t2,
          lastSyncedAt: t1,
          hasLocalData: true,
          hasRemoteData: true,
        ),
        SyncDecision.download,
      );
    });

    test('nenhum mudou desde a última sincronização → em dia', () {
      expect(
        reconcileSync(
          localUpdatedAt: t0,
          remoteUpdatedAt: t0,
          lastSyncedAt: t1,
          hasLocalData: true,
          hasRemoteData: true,
        ),
        SyncDecision.upToDate,
      );
    });

    test('ambos mudaram depois da última sincronização → conflito', () {
      expect(
        reconcileSync(
          localUpdatedAt: t2,
          remoteUpdatedAt: t2.add(const Duration(minutes: 1)),
          lastSyncedAt: t1,
          hasLocalData: true,
          hasRemoteData: true,
        ),
        SyncDecision.conflict,
      );
    });
  });

  group('brands & smartIconFor', () {
    test('detecta marcas com e sem acento e respeita fronteira de palavra', () {
      expect(brandDomainFor('Spotify Família'), 'spotify.com');
      expect(brandDomainFor('Super Mario Odyssey'), 'nintendo.com');
      expect(brandDomainFor('Fatura Itaú'), 'itau.com.br');
      expect(brandDomainFor('Fatura Itau'), 'itau.com.br');
      expect(brandDomainFor('Pão de Açúcar'), 'paodeacucar.com');
      expect(brandDomainFor('Uber pra casa'), 'uber.com');
      expect(brandDomainFor('Supermercado'), isNull);
    });

    test('detecta ícones inteligentes do Lucide para gastos do dia a dia', () {
      expect(smartIconFor('Pizza de sexta'), LucideIcons.pizza);
      expect(smartIconFor('Café da manhã'), LucideIcons.coffee);
      expect(smartIconFor('Gasolina'), LucideIcons.fuel);
      expect(smartIconFor('Mensalidade academia'), LucideIcons.dumbbell);
      expect(smartIconFor('Corte de cabelo'), LucideIcons.scissors);
      expect(smartIconFor('Ração do gato'), LucideIcons.pawPrint);
    });

    test('relaciona jogos exclusivos à plataforma e multiplataforma ao controle', () {
      expect(brandDomainFor('Zelda Tears of the Kingdom'), 'nintendo.com');
      expect(brandDomainFor('God of War Ragnarok'), 'playstation.com');
      expect(brandDomainFor('Forza Horizon 5'), 'xbox.com');
      expect(brandDomainFor('Minecraft'), 'minecraft.net');

      // Jogos multiplataforma: sem marca única, usam controle e caem em Jogos
      expect(brandDomainFor('Elden Ring'), isNull);
      expect(smartIconFor('Elden Ring'), LucideIcons.gamepad2);
      expect(guessCategory('Elden Ring')?.id, 'jogos');
      expect(smartIconFor('Hollow Knight'), LucideIcons.gamepad2);
      expect(guessCategory('Nintendo')?.id, 'jogos');
    });

    test('fornece cores tema oficiais para assinaturas conhecidas', () {
      expect(brandAccentColorFor('Spotify'), const Color(0xFF1DB954));
      expect(brandAccentColorFor('Netflix'), const Color(0xFFE50914));
      expect(brandAccentColorFor('Claude Pro'), const Color(0xFFD97757));
    });

    test('reposiciona gastos antigos nas novas categorias automaticamente', () {
      final d = AppData(
        expenses: [
          Expense(name: 'Nintendo', cents: 644, categoryId: 'outros', date: DateTime.now()),
          Expense(name: 'Switch 2', cents: 35800, categoryId: 'lazer', date: DateTime.now()),
          Expense(name: 'KaBuM SSD', cents: 42000, categoryId: 'compras', date: DateTime.now()),
          Expense(name: 'Ração Cobasi', cents: 12000, categoryId: 'outros', date: DateTime.now()),
        ],
      );
      expect(sanitizeAppData(d), isTrue);
      expect(d.expenses[0].categoryId, 'jogos');
      expect(d.expenses[1].categoryId, 'jogos');
      expect(d.expenses[2].categoryId, 'tecnologia');
      expect(d.expenses[3].categoryId, 'pets');
    });
  });
}
