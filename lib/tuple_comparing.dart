import 'package:quiver/collection.dart' show listsEqual;
import 'package:quiver/iterables.dart' show zip;
import 'package:tuple/tuple.dart';

class TupleComparing implements Comparable<TupleComparing> {
  List<Comparable> items;

  TupleComparing(this.items);

  @override
  int compareTo(TupleComparing other) {
    var cmp = 0;
    for (List<dynamic> pair in zip([items, other.items])) {
      // ignore: avoid_dynamic_calls
      cmp = pair[0].compareTo(pair[1]);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) {
    return other is TupleComparing && listsEqual(items, other.items);
  }

  @override
  int get hashCode => items.hashCode;

  @override
  String toString() => "<TupleComparing $items>";
}

TupleComparing
    toComparable<T1 extends Comparable<T1>, T2 extends Comparable<T2>>(
            Tuple2<T1, T2> other) =>
        TupleComparing(other.toList().map((e) => e as Comparable).toList());
