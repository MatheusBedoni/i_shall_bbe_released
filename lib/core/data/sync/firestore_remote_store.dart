import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_errors.dart';
import 'doc_record.dart';
import 'remote_store.dart';

/// [RemoteStore] sobre `users/{uid}/{coleção}/{id}` no Cloud Firestore.
final class FirestoreRemoteStore implements RemoteStore {
  const FirestoreRemoteStore({required this._db, required this._uid});

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _db.collection('users').doc(_uid).collection(name);

  @override
  Stream<List<DocRecord>> watchCollection(String collection) =>
      _collection(collection)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => DocRecord(d.id, FirestoreCodec.decode(d.data())))
                .toList(),
          )
          .handleError(FirestoreErrors.rethrow_);

  @override
  Future<void> setDoc(String collection, String id, DocData data) =>
      FirestoreErrors.guard(
        () => _collection(collection).doc(id).set(FirestoreCodec.encode(data)),
      );

  @override
  Future<void> deleteDoc(String collection, String id) =>
      FirestoreErrors.guard(() => _collection(collection).doc(id).delete());
}

/// Conversão entre o formato neutro ([DateTime]) e o [Timestamp] do Firestore.
abstract final class FirestoreCodec {
  static Map<String, dynamic> encode(DocData data) =>
      {for (final e in data.entries) e.key: _encode(e.value)};

  static DocData decode(Map<String, dynamic> data) =>
      {for (final e in data.entries) e.key: _decode(e.value)};

  static Object? _encode(Object? v) => switch (v) {
        DateTime d => Timestamp.fromDate(d),
        Map m => {for (final e in m.entries) e.key as String: _encode(e.value)},
        List l => l.map(_encode).toList(),
        _ => v,
      };

  static Object? _decode(Object? v) => switch (v) {
        Timestamp t => t.toDate(),
        Map m => {for (final e in m.entries) e.key as String: _decode(e.value)},
        List l => l.map(_decode).toList(),
        _ => v,
      };
}
