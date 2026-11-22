import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';

const driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';
const driveBackupFileName = 'mare-backup.json';

enum SyncFrequency {
  realtime('Ao alterar', Duration(minutes: 30)),
  every6h('A cada 6 horas', Duration(hours: 6)),
  daily('Uma vez por dia', Duration(hours: 24)),
  manual('Apenas manual', null);

  final String label;
  final Duration? pullInterval;
  const SyncFrequency(this.label, this.pullInterval);
}

enum SyncStatus { disconnected, idle, syncing, error }

enum SyncDecision { upToDate, upload, download, conflict }

/// Metadados do arquivo `mare-backup.json` no Google Drive (`appDataFolder`).
class DriveBackupMeta {
  final String fileId;
  final DateTime? modifiedTime;
  final int? sizeBytes;
  const DriveBackupMeta({
    required this.fileId,
    this.modifiedTime,
    this.sizeBytes,
  });
}

/// Conflito pendente quando tanto o aparelho quanto a nuvem foram alterados
/// desde a última sincronização (ou primeira conexão com dados nos dois lados).
class SyncConflict {
  final DateTime? localUpdatedAt;
  final DateTime? remoteUpdatedAt;
  final String remoteJson;
  final DriveBackupMeta remoteMeta;
  const SyncConflict({
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.remoteJson,
    required this.remoteMeta,
  });
}

/// Resultado de uma tentativa de sincronização.
class SyncResult {
  final bool ok;
  final SyncDecision? decision;
  final String message;
  const SyncResult({
    required this.ok,
    this.decision,
    required this.message,
  });
}

/// Decide de forma pura e segura o que fazer ao comparar o estado local e o da
/// nuvem, evitando sobrescrever alterações silenciosamente.
SyncDecision reconcileSync({
  required DateTime? localUpdatedAt,
  required DateTime? remoteUpdatedAt,
  required DateTime? lastSyncedAt,
  required bool hasLocalData,
  required bool hasRemoteData,
}) {
  if (!hasLocalData && !hasRemoteData) return SyncDecision.upToDate;
  if (hasLocalData && !hasRemoteData) return SyncDecision.upload;
  if (!hasLocalData && hasRemoteData) return SyncDecision.download;

  // Ambos os lados têm dados.
  const skew = Duration(seconds: 2);
  if (lastSyncedAt == null) {
    // Primeira sincronização com dados nos dois lugares: pedir decisão explícita.
    if (localUpdatedAt != null &&
        remoteUpdatedAt != null &&
        localUpdatedAt.difference(remoteUpdatedAt).abs() <= skew) {
      return SyncDecision.upToDate;
    }
    return SyncDecision.conflict;
  }

  final localChanged =
      localUpdatedAt != null && localUpdatedAt.isAfter(lastSyncedAt.add(skew));
  final remoteChanged =
      remoteUpdatedAt != null &&
      remoteUpdatedAt.isAfter(lastSyncedAt.add(skew));

  if (!localChanged && !remoteChanged) return SyncDecision.upToDate;
  if (localChanged && !remoteChanged) return SyncDecision.upload;
  if (!localChanged && remoteChanged) return SyncDecision.download;

  if (localUpdatedAt != null &&
      remoteUpdatedAt != null &&
      localUpdatedAt.difference(remoteUpdatedAt).abs() <= skew) {
    return SyncDecision.upToDate;
  }
  return SyncDecision.conflict;
}

/// Cliente leve para Google Drive API v3 (`appDataFolder`), sem dependências pesadas.
class _DriveAppDataClient {
  static const _filesUrl = 'https://www.googleapis.com/drive/v3/files';
  static const _uploadUrl = 'https://www.googleapis.com/upload/drive/v3/files';

  final http.Client _http;
  _DriveAppDataClient([http.Client? client]) : _http = client ?? http.Client();

  Future<DriveBackupMeta?> findBackup(Map<String, String> headers) async {
    final uri = Uri.parse(_filesUrl).replace(
      queryParameters: {
        'spaces': 'appDataFolder',
        'q': "name='$driveBackupFileName' and trashed=false",
        'fields': 'files(id,modifiedTime,size)',
        'orderBy': 'modifiedTime desc',
        'pageSize': '1',
      },
    );
    final res = await _http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _DriveHttpError(res.statusCode, res.body);
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final files = (decoded['files'] as List?) ?? const [];
    if (files.isEmpty) return null;
    final f = Map<String, dynamic>.from(files.first as Map);
    return DriveBackupMeta(
      fileId: '${f['id']}',
      modifiedTime: f['modifiedTime'] is String
          ? DateTime.tryParse(f['modifiedTime'] as String)?.toUtc()
          : null,
      sizeBytes: int.tryParse('${f['size'] ?? ''}'),
    );
  }

  Future<String> downloadBackup(
    Map<String, String> headers,
    String fileId,
  ) async {
    final uri = Uri.parse(
      '$_filesUrl/${Uri.encodeComponent(fileId)}?alt=media',
    );
    final res = await _http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 25));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _DriveHttpError(res.statusCode, res.body);
    }
    return utf8.decode(res.bodyBytes);
  }

  Future<DriveBackupMeta> uploadBackup(
    Map<String, String> headers,
    String jsonBody, {
    String? existingFileId,
  }) async {
    final bodyBytes = utf8.encode(jsonBody);
    late final http.Response res;

    if (existingFileId != null) {
      final uri = Uri.parse(
        '$_uploadUrl/${Uri.encodeComponent(existingFileId)}?uploadType=media&fields=id,modifiedTime,size',
      );
      res = await _http
          .patch(
            uri,
            headers: {
              ...headers,
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: bodyBytes,
          )
          .timeout(const Duration(seconds: 25));
    } else {
      const boundary = 'mare_drive_sync_boundary_v1';
      final metaJson = jsonEncode({
        'name': driveBackupFileName,
        'parents': ['appDataFolder'],
        'mimeType': 'application/json',
      });
      final multipart = StringBuffer()
        ..write('--$boundary\r\n')
        ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
        ..write(metaJson)
        ..write('\r\n--$boundary\r\n')
        ..write('Content-Type: application/json; charset=UTF-8\r\n\r\n')
        ..write(jsonBody)
        ..write('\r\n--$boundary--\r\n');

      final uri = Uri.parse(
        '$_uploadUrl?uploadType=multipart&fields=id,modifiedTime,size',
      );
      res = await _http
          .post(
            uri,
            headers: {
              ...headers,
              'Content-Type': 'multipart/related; boundary=$boundary',
            },
            body: utf8.encode(multipart.toString()),
          )
          .timeout(const Duration(seconds: 25));
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _DriveHttpError(res.statusCode, res.body);
    }
    final f = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    return DriveBackupMeta(
      fileId: '${f['id']}',
      modifiedTime: f['modifiedTime'] is String
          ? DateTime.tryParse(f['modifiedTime'] as String)?.toUtc()
          : DateTime.now().toUtc(),
      sizeBytes: int.tryParse('${f['size'] ?? ''}') ?? bodyBytes.length,
    );
  }
}

class _DriveHttpError implements Exception {
  final int status;
  final String body;
  const _DriveHttpError(this.status, this.body);
  @override
  String toString() => 'Drive HTTP $status';
}

/// Serviço de sincronização automática e periódica com o Google Drive.
class SyncService extends ChangeNotifier {
  static const _kEnabled = 'mare_sync_enabled';
  static const _kFreq = 'mare_sync_freq';
  static const _kLastSync = 'mare_sync_last';
  static const _kEmail = 'mare_sync_email';
  static const _kName = 'mare_sync_name';
  static const _kPhoto = 'mare_sync_photo';
  static const _kRemoteSize = 'mare_sync_remote_size';
  static const _kRemoteTime = 'mare_sync_remote_time';

  final Store _store;
  final SharedPreferences _prefs;
  final _DriveAppDataClient _api = _DriveAppDataClient();

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _account;
  Timer? _debounce;
  Timer? _periodic;
  bool _disposed = false;
  bool _inFlight = false;
  int _sessionGen = 0;

  SyncStatus _status = SyncStatus.disconnected;
  bool _autoSync = true;
  SyncFrequency _frequency = SyncFrequency.realtime;
  DateTime? _lastSyncedAt;
  DateTime? _remoteModifiedAt;
  int? _remoteSizeBytes;
  String? _accountEmail;
  String? _accountName;
  String? _accountPhotoUrl;
  String? _lastError;
  SyncConflict? _pendingConflict;

  SyncService._(this._store, this._prefs) {
    _autoSync = _prefs.getBool(_kEnabled) ?? true;
    final freqName = _prefs.getString(_kFreq);
    _frequency = SyncFrequency.values.firstWhere(
      (f) => f.name == freqName,
      orElse: () => SyncFrequency.realtime,
    );
    _lastSyncedAt = _parseDate(_prefs.getString(_kLastSync));
    _remoteModifiedAt = _parseDate(_prefs.getString(_kRemoteTime));
    _remoteSizeBytes = _prefs.getInt(_kRemoteSize);
    _accountEmail = _prefs.getString(_kEmail);
    _accountName = _prefs.getString(_kName);
    _accountPhotoUrl = _prefs.getString(_kPhoto);
    if (_accountEmail != null) {
      _status = SyncStatus.idle;
    }
    _store.onLocalChange = notifyLocalChange;
  }

  static SyncService attach(Store store, {bool restoreSession = true}) {
    final svc = SyncService._(store, store.prefs);
    if (restoreSession &&
        svc._accountEmail != null &&
        store.data.onboardingDone) {
      unawaited(svc._restoreSilentSession());
    }
    return svc;
  }

  static DateTime? _parseDate(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw)?.toUtc();

  // ── Estado público ────────────────────────────────────────

  SyncStatus get status => _status;
  bool get isConnected => _accountEmail != null;
  bool get isSyncing => _status == SyncStatus.syncing;
  bool get autoSync => _autoSync;
  SyncFrequency get frequency => _frequency;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  DateTime? get remoteModifiedAt => _remoteModifiedAt;
  int? get remoteSizeBytes => _remoteSizeBytes;
  String? get accountEmail => _accountEmail;
  String? get accountName => _accountName;
  String? get accountPhotoUrl => _accountPhotoUrl;
  String? get lastError => _lastError;
  SyncConflict? get pendingConflict => _pendingConflict;

  bool get isSupportedPlatform => !kIsWeb;

  /// Verdadeiro quando existem dados locais que ainda não foram enviados ao Drive.
  bool get hasUnsyncedChanges {
    if (!isConnected) return _store.hasMeaningfulData;
    if (_pendingConflict != null) return true;
    final last = _lastSyncedAt;
    if (last == null) return _store.hasMeaningfulData;
    final local = _store.data.updatedAt;
    if (local == null) return false;
    return local.isAfter(last.add(const Duration(seconds: 2)));
  }

  GoogleSignIn _ensureSignIn() =>
      _googleSignIn ??= GoogleSignIn(scopes: const [driveAppDataScope]);

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _savePrefs() {
    _prefs.setBool(_kEnabled, _autoSync);
    _prefs.setString(_kFreq, _frequency.name);
    if (_lastSyncedAt != null) {
      _prefs.setString(_kLastSync, _lastSyncedAt!.toUtc().toIso8601String());
    } else {
      _prefs.remove(_kLastSync);
    }
    if (_remoteModifiedAt != null) {
      _prefs.setString(
        _kRemoteTime,
        _remoteModifiedAt!.toUtc().toIso8601String(),
      );
    } else {
      _prefs.remove(_kRemoteTime);
    }
    if (_remoteSizeBytes != null) {
      _prefs.setInt(_kRemoteSize, _remoteSizeBytes!);
    } else {
      _prefs.remove(_kRemoteSize);
    }
    if (_accountEmail != null) {
      _prefs.setString(_kEmail, _accountEmail!);
    } else {
      _prefs.remove(_kEmail);
    }
    if (_accountName != null) {
      _prefs.setString(_kName, _accountName!);
    } else {
      _prefs.remove(_kName);
    }
    if (_accountPhotoUrl != null) {
      _prefs.setString(_kPhoto, _accountPhotoUrl!);
    } else {
      _prefs.remove(_kPhoto);
    }
  }

  void _startPeriodicTimer() {
    _periodic?.cancel();
    if (!isConnected || !_autoSync || _frequency == SyncFrequency.manual) return;
    _periodic = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _syncIfDue(),
    );
  }

  Future<void> _restoreSilentSession() async {
    if (!isSupportedPlatform || !_store.data.onboardingDone) return;
    try {
      final acc = await _ensureSignIn().signInSilently();
      if (_disposed || !_store.data.onboardingDone) return;
      if (acc != null) {
        _setAccount(acc);
        _startPeriodicTimer();
        await _syncIfDue();
      }
    } catch (_) {
      // Sem rede ou plugin indisponível (ex.: testes); mantém cache local.
    }
  }

  void _setAccount(GoogleSignInAccount acc) {
    _account = acc;
    _accountEmail = acc.email;
    _accountName = acc.displayName;
    _accountPhotoUrl = acc.photoUrl;
    if (_status == SyncStatus.disconnected) _status = SyncStatus.idle;
    _savePrefs();
    _emit();
  }

  // ── Preferências ──────────────────────────────────────────

  void setAutoSync(bool enabled) {
    _autoSync = enabled;
    _savePrefs();
    if (enabled) {
      _startPeriodicTimer();
    } else {
      _debounce?.cancel();
      _periodic?.cancel();
    }
    _emit();
  }

  void setFrequency(SyncFrequency freq) {
    _frequency = freq;
    _savePrefs();
    _startPeriodicTimer();
    _emit();
  }

  // ── Gatilhos automáticos ──────────────────────────────────

  void notifyLocalChange() {
    if (!_store.data.onboardingDone ||
        !isConnected ||
        !_autoSync ||
        _frequency != SyncFrequency.realtime) {
      return;
    }
    if (_pendingConflict != null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), () {
      if (!_disposed &&
          _store.data.onboardingDone &&
          isConnected &&
          _autoSync) {
        unawaited(syncNow(silent: true));
      }
    });
  }

  void onAppResumed() {
    if (!_store.data.onboardingDone || !isConnected || !_autoSync) return;
    unawaited(_syncIfDue());
  }

  Future<void> _syncIfDue() async {
    if (!_store.data.onboardingDone ||
        !isConnected ||
        !_autoSync ||
        _pendingConflict != null) {
      return;
    }
    final interval = _frequency.pullInterval;
    if (interval == null) return;
    final last = _lastSyncedAt;
    if (last == null || DateTime.now().toUtc().difference(last) >= interval) {
      await syncNow(silent: true);
    }
  }

  // ── Conexão com o Google ──────────────────────────────────

  Future<SyncResult> connect() async {
    if (!isSupportedPlatform) {
      return const SyncResult(
        ok: false,
        message: 'A sincronização com Google Drive funciona no app Android.',
      );
    }
    if (_inFlight) {
      return const SyncResult(
        ok: false,
        message: 'Sincronização já em andamento.',
      );
    }
    final gen = _sessionGen;
    _lastError = null;
    _status = SyncStatus.syncing;
    _emit();
    try {
      final acc = await _ensureSignIn().signIn();
      if (_disposed || gen != _sessionGen) {
        return const SyncResult(ok: false, message: 'Sessão encerrada.');
      }
      if (acc == null) {
        _status = isConnected ? SyncStatus.idle : SyncStatus.disconnected;
        _emit();
        return const SyncResult(ok: false, message: 'Login cancelado.');
      }
      _setAccount(acc);
      _startPeriodicTimer();
      return await syncNow();
    } catch (e) {
      if (_disposed || gen != _sessionGen) {
        return const SyncResult(ok: false, message: 'Sessão encerrada.');
      }
      final msg = _friendlyError(e);
      _lastError = msg;
      _status = isConnected ? SyncStatus.error : SyncStatus.disconnected;
      _emit();
      return SyncResult(ok: false, message: msg);
    }
  }

  Future<void> disconnect() async {
    _sessionGen++;
    _debounce?.cancel();
    _periodic?.cancel();
    try {
      if (isSupportedPlatform) {
        await _ensureSignIn().signOut();
      }
    } catch (_) {}
    _account = null;
    _accountEmail = null;
    _accountName = null;
    _accountPhotoUrl = null;
    _lastSyncedAt = null;
    _remoteModifiedAt = null;
    _remoteSizeBytes = null;
    _pendingConflict = null;
    _lastError = null;
    _status = SyncStatus.disconnected;
    _savePrefs();
    _emit();
  }

  Future<Map<String, String>?> _authHeaders({required bool silent}) async {
    if (!isSupportedPlatform) return null;
    final gs = _ensureSignIn();
    _account ??= gs.currentUser ?? await gs.signInSilently();
    if (_account == null && !silent) {
      _account = await gs.signIn();
    }
    if (_account == null) return null;
    _setAccount(_account!);
    return _account!.authHeaders;
  }

  // ── Sincronização principal ───────────────────────────────

  Future<SyncResult> syncNow({bool silent = false}) async {
    if (_inFlight) {
      return const SyncResult(
        ok: false,
        message: 'Sincronização já em andamento.',
      );
    }
    if (!isConnected && silent) {
      return const SyncResult(ok: false, message: 'Conta não conectada.');
    }
    final gen = _sessionGen;
    _inFlight = true;
    _lastError = null;
    _status = SyncStatus.syncing;
    _emit();

    try {
      final headers = await _authHeaders(silent: silent);
      if (_disposed || gen != _sessionGen) {
        return const SyncResult(ok: false, message: 'Sessão encerrada.');
      }
      if (headers == null) {
        _status = isConnected ? SyncStatus.idle : SyncStatus.disconnected;
        _emit();
        return const SyncResult(
          ok: false,
          message: 'Sessão do Google expirou. Conecte novamente.',
        );
      }

      final remoteMeta = await _api.findBackup(headers);
      if (_disposed || gen != _sessionGen) {
        return const SyncResult(ok: false, message: 'Sessão encerrada.');
      }
      String? remoteJson;
      DateTime? remoteUpdatedAt = remoteMeta?.modifiedTime;
      if (remoteMeta != null) {
        remoteJson = await _api.downloadBackup(headers, remoteMeta.fileId);
        if (_disposed || gen != _sessionGen) {
          return const SyncResult(ok: false, message: 'Sessão encerrada.');
        }
        remoteUpdatedAt = _extractUpdatedAt(remoteJson) ?? remoteMeta.modifiedTime;
        _remoteModifiedAt = remoteUpdatedAt;
        _remoteSizeBytes = remoteMeta.sizeBytes ?? utf8.encode(remoteJson).length;
      }

      final localSnapshotTs = _store.data.updatedAt ?? DateTime.now().toUtc();
      final hasLocal = _store.hasMeaningfulData;
      final hasRemote = remoteMeta != null && remoteJson != null;
      final decision = reconcileSync(
        localUpdatedAt: _store.data.updatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
        lastSyncedAt: _lastSyncedAt,
        hasLocalData: hasLocal,
        hasRemoteData: hasRemote,
      );

      switch (decision) {
        case SyncDecision.upToDate:
          _pendingConflict = null;
          if (hasLocal || hasRemote) {
            _lastSyncedAt = DateTime.now().toUtc();
          }
          _status = SyncStatus.idle;
          _savePrefs();
          _emit();
          return const SyncResult(
            ok: true,
            decision: SyncDecision.upToDate,
            message: 'Tudo já está em dia',
          );

        case SyncDecision.upload:
          final meta = await _api.uploadBackup(
            headers,
            _store.exportJson(),
            existingFileId: remoteMeta?.fileId,
          );
          if (_disposed || gen != _sessionGen) {
            return const SyncResult(ok: false, message: 'Sessão encerrada.');
          }
          _pendingConflict = null;
          _remoteModifiedAt = meta.modifiedTime ?? DateTime.now().toUtc();
          _remoteSizeBytes = meta.sizeBytes;
          _lastSyncedAt = localSnapshotTs;
          _status = SyncStatus.idle;
          _savePrefs();
          _emit();
          return const SyncResult(
            ok: true,
            decision: SyncDecision.upload,
            message: 'Backup enviado ao Google Drive',
          );

        case SyncDecision.download:
          final err = _store.importJson(
            remoteJson!,
            fromCloud: true,
            cloudUpdatedAt: remoteUpdatedAt,
          );
          if (err != null) {
            _lastError = err;
            _status = SyncStatus.error;
            _emit();
            return SyncResult(ok: false, message: err);
          }
          final nowUtc = DateTime.now().toUtc();
          _pendingConflict = null;
          _lastSyncedAt =
              remoteUpdatedAt != null && remoteUpdatedAt.isAfter(nowUtc)
                  ? remoteUpdatedAt
                  : nowUtc;
          _status = SyncStatus.idle;
          _savePrefs();
          _emit();
          return const SyncResult(
            ok: true,
            decision: SyncDecision.download,
            message: 'Dados restaurados do Google Drive',
          );

        case SyncDecision.conflict:
          _pendingConflict = SyncConflict(
            localUpdatedAt: _store.data.updatedAt,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteJson: remoteJson!,
            remoteMeta: remoteMeta!,
          );
          _status = SyncStatus.idle;
          _savePrefs();
          _emit();
          return const SyncResult(
            ok: false,
            decision: SyncDecision.conflict,
            message: 'Há alterações tanto neste celular quanto no Google Drive.',
          );
      }
    } catch (e) {
      final msg = _friendlyError(e);
      _lastError = msg;
      _status = SyncStatus.error;
      _emit();
      return SyncResult(ok: false, message: msg);
    } finally {
      _inFlight = false;
    }
  }

  /// Força o envio dos dados deste aparelho para o Google Drive (sobrescreve a nuvem).
  Future<SyncResult> pushNow() async {
    if (_inFlight) {
      return const SyncResult(
        ok: false,
        message: 'Sincronização já em andamento.',
      );
    }
    _inFlight = true;
    _lastError = null;
    _status = SyncStatus.syncing;
    _emit();
    try {
      final headers = await _authHeaders(silent: false);
      if (headers == null) {
        _status = isConnected ? SyncStatus.idle : SyncStatus.disconnected;
        _emit();
        return const SyncResult(
          ok: false,
          message: 'Conecte sua conta Google para enviar o backup.',
        );
      }
      final existing =
          _pendingConflict?.remoteMeta ?? await _api.findBackup(headers);
      final meta = await _api.uploadBackup(
        headers,
        _store.exportJson(),
        existingFileId: existing?.fileId,
      );
      _pendingConflict = null;
      _remoteModifiedAt = meta.modifiedTime ?? DateTime.now().toUtc();
      _remoteSizeBytes = meta.sizeBytes;
      _lastSyncedAt = DateTime.now().toUtc();
      _status = SyncStatus.idle;
      _savePrefs();
      _emit();
      return const SyncResult(
        ok: true,
        decision: SyncDecision.upload,
        message: 'Backup enviado ao Google Drive',
      );
    } catch (e) {
      final msg = _friendlyError(e);
      _lastError = msg;
      _status = SyncStatus.error;
      _emit();
      return SyncResult(ok: false, message: msg);
    } finally {
      _inFlight = false;
    }
  }

  /// Força a restauração da cópia salva no Google Drive (sobrescreve este aparelho).
  Future<SyncResult> pullNow() async {
    if (_inFlight) {
      return const SyncResult(
        ok: false,
        message: 'Sincronização já em andamento.',
      );
    }
    _inFlight = true;
    _lastError = null;
    _status = SyncStatus.syncing;
    _emit();
    try {
      final headers = await _authHeaders(silent: false);
      if (headers == null) {
        _status = isConnected ? SyncStatus.idle : SyncStatus.disconnected;
        _emit();
        return const SyncResult(
          ok: false,
          message: 'Conecte sua conta Google para restaurar o backup.',
        );
      }
      String raw;
      DateTime? remoteTime;
      int? remoteSize;
      if (_pendingConflict != null) {
        raw = _pendingConflict!.remoteJson;
        remoteTime = _pendingConflict!.remoteUpdatedAt;
        remoteSize = _pendingConflict!.remoteMeta.sizeBytes;
      } else {
        final meta = await _api.findBackup(headers);
        if (meta == null) {
          _status = SyncStatus.idle;
          _emit();
          return const SyncResult(
            ok: false,
            message: 'Nenhum backup encontrado no seu Google Drive ainda.',
          );
        }
        raw = await _api.downloadBackup(headers, meta.fileId);
        remoteTime = _extractUpdatedAt(raw) ?? meta.modifiedTime;
        remoteSize = meta.sizeBytes ?? utf8.encode(raw).length;
      }
      final err = _store.importJson(
        raw,
        fromCloud: true,
        cloudUpdatedAt: remoteTime,
      );
      if (err != null) {
        _lastError = err;
        _status = SyncStatus.error;
        _emit();
        return SyncResult(ok: false, message: err);
      }
      _pendingConflict = null;
      _remoteModifiedAt = remoteTime;
      _remoteSizeBytes = remoteSize;
      _lastSyncedAt = DateTime.now().toUtc();
      _status = SyncStatus.idle;
      _savePrefs();
      _emit();
      return const SyncResult(
        ok: true,
        decision: SyncDecision.download,
        message: 'Backup restaurado do Google Drive',
      );
    } catch (e) {
      final msg = _friendlyError(e);
      _lastError = msg;
      _status = SyncStatus.error;
      _emit();
      return SyncResult(ok: false, message: msg);
    } finally {
      _inFlight = false;
    }
  }

  DateTime? _extractUpdatedAt(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['updatedAt'] is String) {
        return DateTime.tryParse(decoded['updatedAt'] as String)?.toUtc();
      }
    } catch (_) {}
    return null;
  }

  String _friendlyError(Object e) {
    if (e is PlatformException) {
      final msg = '${e.code} ${e.message ?? ''}'.toLowerCase();
      if (RegExp(r'\b10\b').hasMatch(msg) || msg.contains('developer_error')) {
        return 'Login Google não configurado no Google Cloud Console (erro 10: verifique o Client ID Android e o SHA-1).';
      }
      if (msg.contains('network') || RegExp(r'\b7\b').hasMatch(msg)) {
        return 'Sem conexão com a internet para falar com o Google Drive.';
      }
      if (msg.contains('sign_in_canceled')) {
        return 'Login cancelado.';
      }
    }
    if (e is _DriveHttpError) {
      if (e.status == 401 || e.status == 403) {
        return 'Permissão do Google Drive negada ou Google Drive API desativada no projeto.';
      }
      return 'O Google Drive respondeu com erro (${e.status}). Tente novamente.';
    }
    if (e is TimeoutException) {
      return 'Tempo esgotado ao conectar com o Google Drive.';
    }
    return 'Não foi possível sincronizar agora. Verifique sua conexão.';
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _periodic?.cancel();
    _api._http.close();
    if (_store.onLocalChange == notifyLocalChange) {
      _store.onLocalChange = null;
    }
    super.dispose();
  }
}

class SyncScope extends InheritedNotifier<SyncService> {
  const SyncScope({
    super.key,
    required SyncService sync,
    required super.child,
  }) : super(notifier: sync);

  static SyncService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()!.notifier!;
  static SyncService read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SyncScope>()!.notifier!;
}

extension SyncX on BuildContext {
  SyncService get sync => SyncScope.of(this);
  SyncService get syncRead => SyncScope.read(this);
}
