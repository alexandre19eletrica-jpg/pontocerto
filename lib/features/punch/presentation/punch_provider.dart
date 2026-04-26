import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/core/firebase/firebase_status.dart';
import 'package:pontocerto/features/audit/presentation/audit_provider.dart';
import 'package:pontocerto/features/device_consent/presentation/device_consent_provider.dart';
import 'package:pontocerto/features/punch/domain/punch.dart';

class PunchNotifier extends Notifier<List<Punch>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<Punch> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bindStream(firebaseDisponivel, sessao);
    return <Punch>[];
  }

  void _bindStream(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <Punch>[];
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    Query<Map<String, dynamic>> query;

    if (sessao.role == Role.employee) {
      query = FirebaseFirestore.instance
          .collection('punches')
          .where('employeeId', isEqualTo: currentUid);
    } else {
      query = FirebaseFirestore.instance
          .collection('punches')
          .where('companyId', isEqualTo: sessao.companyId);
    }

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [for (final doc in snapshot.docs) _fromDoc(doc)]
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      },
      onError: (error, stackTrace) {
        debugPrint('punchProvider stream error: $error');
      },
    );
  }

  Punch _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final timestamp = map['timestamp'];
    final data = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.tryParse(timestamp?.toString() ?? '') ?? DateTime.now();

    final tipoTexto = map['tipo']?.toString() ?? PunchType.entrada.name;

    return Punch(
      id: doc.id,
      employeeId: map['employeeId']?.toString() ?? '',
      timestamp: data,
      tipo: tipoTexto == PunchType.saida.name ? PunchType.saida : PunchType.entrada,
      obraOuCliente: map['obraOuCliente']?.toString() ?? '',
    );
  }

  Future<void> register({
    required String employeeId,
    required String obraOuCliente,
  }) async {
    final sessao = ref.read(sessionProvider);
    if (sessao == null) throw Exception('Sessao nao encontrada.');
    await _ensureEmployeeDeviceConsent(sessao, employeeId);

    PunchType proximoTipo = PunchType.entrada;
    for (final item in state.reversed) {
      if (item.employeeId == employeeId) {
        proximoTipo =
            item.tipo == PunchType.entrada ? PunchType.saida : PunchType.entrada;
        break;
      }
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final snapshotAnterior = state;
    final novo = Punch(
      id: id,
      employeeId: employeeId,
      timestamp: DateTime.now(),
      tipo: proximoTipo,
      obraOuCliente: obraOuCliente,
    );
    state = [...state, novo];

    try {
      await FirebaseFirestore.instance.collection('punches').doc(id).set({
        'companyId': sessao.companyId,
        'employeeId': employeeId,
        'timestamp': FieldValue.serverTimestamp(),
        'tipo': proximoTipo.name,
        'obraOuCliente': obraOuCliente,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }

    try {
      await _autoCloseOpenDays(
        companyId: sessao.companyId,
        employeeId: employeeId,
      );
      await _upsertWorkedDay(
        companyId: sessao.companyId,
        employeeId: employeeId,
        punchType: proximoTipo,
      );
    } catch (_) {
      // Registro de ponto principal nao deve falhar por erro auxiliar de dias trabalhados.
    }

    _registrarAuditoria('register');
  }

  Future<void> remove(String id) async {
    final snapshotAnterior = state;
    state = [for (final item in state) if (item.id != id) item];
    try {
      await FirebaseFirestore.instance.collection('punches').doc(id).delete();
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }
    _registrarAuditoria('remove');
  }

  void _registrarAuditoria(String acao) {
    try {
      ref.read(auditProvider.notifier).log(modulo: 'punch', acao: acao);
    } catch (_) {
      // Nao bloqueia o fluxo principal se auditoria falhar.
    }
  }

  Future<void> _autoCloseOpenDays({
    required String companyId,
    required String employeeId,
  }) async {
    final hoje = DateTime.now();
    final chaveHoje = _dateKey(hoje);

    final query = await FirebaseFirestore.instance
        .collection('worked_days')
        .where('companyId', isEqualTo: companyId)
        .where('employeeId', isEqualTo: employeeId)
        .where('hasExit', isEqualTo: false)
        .get();

    for (final doc in query.docs) {
      final key = doc.data()['dateKey']?.toString() ?? '';
      if (key.isNotEmpty && key.compareTo(chaveHoje) < 0) {
        await doc.reference.set({
          'hasExit': true,
          'autoClosed': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> _upsertWorkedDay({
    required String companyId,
    required String employeeId,
    required PunchType punchType,
  }) async {
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    final key = _dateKey(dateOnly);
    final docId = '${employeeId}_$key';

    final hasEntry = punchType == PunchType.entrada;
    final hasExit = punchType == PunchType.saida;

    await FirebaseFirestore.instance.collection('worked_days').doc(docId).set({
      'companyId': companyId,
      'employeeId': employeeId,
      'date': Timestamp.fromDate(dateOnly),
      'dateKey': key,
      'period': 'FULL',
      'hasEntry': hasEntry,
      'hasExit': hasExit,
      'autoClosed': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _dateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  Future<void> _ensureEmployeeDeviceConsent(Session sessao, String employeeId) async {
    if (sessao.role != Role.employee) return;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    if (uid != employeeId) return;

    final consent = ref
        .read(deviceConsentsProvider)
        .where((c) => c.employeeId == uid && c.companyId == sessao.companyId)
        .firstOrNull;
    if (consent != null && consent.accepted) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('device_consents').doc(uid).get();
      final map = doc.data();
      final accepted = map?['accepted'] == true;
      final companyId = map?['companyId']?.toString();
      if (accepted && companyId == sessao.companyId) return;
    } catch (_) {
      // fallback no erro abaixo
    }

    throw Exception(
      'Para bater ponto pelo proprio celular, autorize primeiro o uso do dispositivo no app.',
    );
  }
}

final punchProvider = NotifierProvider<PunchNotifier, List<Punch>>(
  PunchNotifier.new,
);

class WorkedDaysNotifier extends Notifier<List<WorkedDay>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<WorkedDay> build() {
    ref.onDispose(() => _sub?.cancel());
    final firebaseDisponivel = ref.watch(firebaseAvailableProvider);
    final sessao = ref.watch(sessionProvider);
    _bind(firebaseDisponivel, sessao);
    return <WorkedDay>[];
  }

  void _bind(bool firebaseDisponivel, Session? sessao) {
    _sub?.cancel();
    if (!firebaseDisponivel || sessao == null) {
      state = <WorkedDay>[];
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? sessao.userId;
    Query<Map<String, dynamic>> query;

    if (sessao.role == Role.employee) {
      query = FirebaseFirestore.instance
          .collection('worked_days')
          .where('employeeId', isEqualTo: currentUid);
    } else {
      query = FirebaseFirestore.instance
          .collection('worked_days')
          .where('companyId', isEqualTo: sessao.companyId);
    }

    _sub = query.snapshots().listen(
      (snapshot) {
        state = [for (final doc in snapshot.docs) _fromDoc(doc)]
          ..sort((a, b) => b.date.compareTo(a.date));
      },
      onError: (error, stackTrace) {
        debugPrint('workedDaysProvider stream error: $error');
      },
    );
  }

  WorkedDay _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? <String, dynamic>{};
    final dateRaw = map['date'];
    final date = dateRaw is Timestamp
        ? dateRaw.toDate()
        : DateTime.tryParse(dateRaw?.toString() ?? '') ?? DateTime.now();
    final periodRaw = (map['period'] ?? 'FULL').toString().toUpperCase();
    return WorkedDay(
      id: doc.id,
      employeeId: map['employeeId']?.toString() ?? '',
      date: date,
      period: periodRaw == 'HALF'
          ? WorkedDayPeriod.halfDay
          : WorkedDayPeriod.fullDay,
      hasEntry: map['hasEntry'] == true,
      hasExit: map['hasExit'] == true,
      autoClosed: map['autoClosed'] == true,
    );
  }

  Future<void> setPeriod(String workedDayId, WorkedDayPeriod period) async {
    await FirebaseFirestore.instance.collection('worked_days').doc(workedDayId).set({
      'period': period == WorkedDayPeriod.fullDay ? 'FULL' : 'HALF',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> remove(String workedDayId) async {
    final snapshotAnterior = state;
    state = [for (final item in state) if (item.id != workedDayId) item];
    try {
      await FirebaseFirestore.instance.collection('worked_days').doc(workedDayId).delete();
    } catch (e) {
      state = snapshotAnterior;
      rethrow;
    }
  }
}

final workedDaysProvider = NotifierProvider<WorkedDaysNotifier, List<WorkedDay>>(
  WorkedDaysNotifier.new,
);


