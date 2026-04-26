import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pontocerto/core/auth/session.dart';
import 'package:pontocerto/features/document_drafts/domain/document_request.dart';

class DocumentRequestsController
    extends Notifier<List<CompanyDocumentRequest>> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  List<CompanyDocumentRequest> build() {
    ref.onDispose(() => _sub?.cancel());
    final session = ref.watch(sessionProvider);
    _bind(session);
    return const <CompanyDocumentRequest>[];
  }

  void _bind(Session? session) {
    _sub?.cancel();
    if (session == null) {
      state = const <CompanyDocumentRequest>[];
      return;
    }
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'document_requests',
    );
    if (session.role == Role.employee) {
      query = query.where(
        'currentResponsibleEmployeeIds',
        arrayContains: session.userId,
      );
    } else {
      query = query.where('companyId', isEqualTo: session.companyId);
    }
    _sub = query.snapshots().listen(
      (snapshot) {
        state =
            [
              for (final doc in snapshot.docs)
                CompanyDocumentRequest.fromMap({...doc.data(), 'id': doc.id}),
            ]..sort((a, b) {
              final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
              final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
              return bDate.compareTo(aDate);
            });
      },
      onError: (error) =>
          debugPrint('documentRequestsProvider stream error: $error'),
    );
  }

  Future<void> add(CompanyDocumentRequest request) async {
    final previous = state;
    state = [request, ...state.where((item) => item.id != request.id)];
    try {
      await FirebaseFirestore.instance
          .collection('document_requests')
          .doc(request.id)
          .set({
            ...request.toMap(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error) {
      state = previous;
      rethrow;
    }
  }

  Future<void> update(CompanyDocumentRequest request) async {
    final previous = state;
    state =
        [
          for (final item in state)
            if (item.id == request.id) request else item,
        ]..sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
          final bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
    try {
      await FirebaseFirestore.instance
          .collection('document_requests')
          .doc(request.id)
          .set({
            ...request.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
            'completedAt': request.completedAt == null
                ? null
                : Timestamp.fromDate(request.completedAt!),
          }, SetOptions(merge: true));
    } catch (error) {
      state = previous;
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    final previous = state;
    state = state.where((item) => item.id != id).toList();
    try {
      await FirebaseFirestore.instance
          .collection('document_requests')
          .doc(id)
          .delete();
    } catch (error) {
      state = previous;
      rethrow;
    }
  }
}

final documentRequestsProvider =
    NotifierProvider<DocumentRequestsController, List<CompanyDocumentRequest>>(
      DocumentRequestsController.new,
    );
