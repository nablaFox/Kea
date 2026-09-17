import std/math, vector

type
  Matrix*[R, C: static int] = array[R, Vec[C]]
  Mat3* = Matrix[3, 3]
  Mat4* = Matrix[4, 4]

proc identity*[C: static int](): Matrix[C, C] =
  for i in 0..<C:
    result[i][i] = 1.0

const
  Identity3* = identity[3]()
  Identity4* = identity[4]()

proc `*`*[R, N, C: static int](
  a: Matrix[R, N],
  b: Matrix[N, C]
): Matrix[R, C] =
  for row in 0..<R:
    for col in 0..<C:
      for k in 0..<N:
        result[row][col] += a[row][k] * b[k][col]

proc `*=`*[R, N, C: static int](
  a: var Matrix[R, N],
  b: Matrix[N, C]
) =
  a = a * b

proc `*`*[R, C: static int](m: Matrix[R, C], v: Vec[C]): Vec[R] =
  for row in 0..<R:
    for col in 0..<C:
      result[row] += m[row][col] * v[col]

proc transpose*[R, C: static int](m: Matrix[R, C]): Matrix[C, R] =
  for row in 0..<R:
    for col in 0..<C:
      result[col][row] = m[row][col]

proc inverse*[C: static int](m: Matrix[C, C]): Matrix[C, C] =
  var a = m
  result = identity[C]()

  for col in 0..<C:
    var pivot = col

    for row in col + 1..<C:
      if abs(a[row][col]) > abs(a[pivot][col]):
        pivot = row

    if abs(a[pivot][col]) < 1e-7'f:
      raise newException(ValueError, "matrix is singular")

    swap(a[col], a[pivot])
    swap(result[col], result[pivot])

    let divisor = a[col][col]

    for j in 0..<C:
      a[col][j] /= divisor
      result[col][j] /= divisor

    for row in 0..<C:
      if row != col:
        let factor = a[row][col]

        for j in 0..<C:
          a[row][j] -= factor * a[col][j]
          result[row][j] -= factor * result[col][j]

# TODO: implement in general
proc det*(m: Mat3): float32 =
  m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
  m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
  m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])

proc upper*[R, C: static int](
  m: Matrix[R, C],
  N: static int
): Matrix[N, N] =
  static:
    doAssert N <= R and N <= C

  for row in 0..<N:
    for col in 0..<N:
      result[row][col] = m[row][col]
