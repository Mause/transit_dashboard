class Pair<L, R> {
  L left;
  R right;

  Pair(this.left, this.right);

  factory Pair.of(L left, R right) => Pair(left, right);
}
