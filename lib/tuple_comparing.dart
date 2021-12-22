import 'package:quiver/collection.dart' show listsEqual;
import 'package:quiver/iterables.dart' show zip;

class TupleComparing implements Comparable<TupleComparing> {
  List<dynamic> items;

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
