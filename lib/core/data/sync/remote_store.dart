import 'doc_record.dart';

/// Acesso ao espelho remoto das coleções do usuário. Abstrai o Firestore para
/// que o motor de sync seja testável com uma implementação em memória.
abstract interface class RemoteStore {
  /// Emite o conteúdo **completo** da coleção a cada mudança remota.
  Stream<List<DocRecord>> watchCollection(String collection);

  /// Cria ou substitui o documento inteiro.
  Future<void> setDoc(String collection, String id, DocData data);

  Future<void> deleteDoc(String collection, String id);
}
