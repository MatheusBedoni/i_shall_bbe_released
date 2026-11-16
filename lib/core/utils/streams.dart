import 'dart:async';

/// Combina dois streams emitindo sempre que qualquer um deles emite, depois
/// que ambos já emitiram ao menos uma vez (como `combineLatest` do rxdart).
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A a, B b) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  var hasA = false;
  var hasB = false;
  late A lastA;
  late B lastB;

  void emit() {
    if (hasA && hasB) controller.add(combine(lastA, lastB));
  }

  var doneCount = 0;
  void onDone() {
    if (++doneCount == 2) controller.close();
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen(
        (v) {
          lastA = v;
          hasA = true;
          emit();
        },
        onError: controller.addError,
        onDone: onDone,
      );
      subB = b.listen(
        (v) {
          lastB = v;
          hasB = true;
          emit();
        },
        onError: controller.addError,
        onDone: onDone,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}
