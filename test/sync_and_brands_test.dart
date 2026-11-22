import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mare/data/brands.dart';
import 'package:mare/data/drive_sync.dart';

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
  });
}
