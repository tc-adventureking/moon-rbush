test "quickselect sampled path and duplicates preserve partitions" {
  for size in [1, 7, 601, 2000] {
    for k in [0, size / 2, size - 1] {
      let a = Array::makei(size, i => (i * 7919 + 23) % 101)
      let sorted = a.copy()
      sorted.sort()
      quickselect(a, k, 0, size - 1, (a,b) => a.compare(b))
      assert_eq(a[k], sorted[k])
      for i = 0; i < k; i = i + 1 { assert_true(a[i] <= a[k]) }
      for i = k + 1; i < size; i = i + 1 { assert_true(a[i] >= a[k]) }
      a.sort()
      assert_eq(a, sorted)
    }
  }
}
test "multiSelect partitions contiguous blocks" {
  let a = Array::makei(1000, i => (i * 7919) % 1000)
  multi_select(a, 0, 999, 20, (a,b) => a.compare(b))
  for boundary = 20; boundary < 1000; boundary = boundary + 20 {
    for i = 0; i < boundary; i = i + 1 { assert_true(a[i] <= a[boundary]) }
  }
}

