// Port of mourner/quickselect 3.0.0 (ISC); see THIRD_PARTY_NOTICES.md.

///|
fn[T] swap(a : Array[T], i : Int32, j : Int32) -> Unit {
  let t = a[i]
  a[i] = a[j]
  a[j] = t
}

///|
fn[T] quickselect(
  a : Array[T],
  k : Int32,
  left0 : Int32,
  right0 : Int32,
  cmp : (T, T) -> Int32,
) -> Unit {
  let mut left = left0
  let mut right = right0
  while right > left {
    if right - left > 600 {
      let n = (right - left + 1).to_double()
      let m = (k - left + 1).to_double()
      let z = @math.ln(n)
      let s = 0.5 * @math.exp(2.0 * z / 3.0)
      let sd = 0.5 *
        (z * s * (n - s) / n).sqrt() *
        (if m - n / 2.0 < 0.0 { -1.0 } else { 1.0 })
      let nl = @double.floor(k.to_double() - m * s / n + sd).to_int()
      let nr = @double.floor(k.to_double() + (n - m) * s / n + sd).to_int()
      quickselect(
        a,
        k,
        if nl > left {
          nl
        } else {
          left
        },
        if nr < right {
          nr
        } else {
          right
        },
        cmp,
      )
    }
    let t = a[k]
    let mut i = left
    let mut j = right
    swap(a, left, k)
    if cmp(a[right], t) > 0 {
      swap(a, left, right)
    }
    while i < j {
      swap(a, i, j)
      i += 1
      j -= 1
      while cmp(a[i], t) < 0 {
        i += 1
      }
      while cmp(a[j], t) > 0 {
        j -= 1
      }
    }
    if cmp(a[left], t) == 0 {
      swap(a, left, j)
    } else {
      j += 1
      swap(a, j, right)
    }
    if j <= k {
      left = j + 1
    }
    if k <= j {
      right = j - 1
    }
  }
}

///|
fn[T] multi_select(
  a : Array[T],
  left : Int32,
  right : Int32,
  n : Int32,
  cmp : (T, T) -> Int32,
) -> Unit {
  let stack = [(left, right)]
  while stack.length() > 0 {
    let (l, r) = stack.unsafe_pop()
    if r - l > n {
      let mid = l +
        ((r - l).to_double() / n.to_double() / 2.0).ceil().to_int() * n
      quickselect(a, mid, l, r, cmp)
      stack.push((l, mid))
      stack.push((mid, r))
    }
  }
}
