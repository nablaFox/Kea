type 
  Vec*[C: static int] = array[C, float32]
  Matrix*[R, C: static int] = array[R, Vec[C]]

  Vec2* = Vec[2]
  Vec3* = Vec[3]
  Vec4* = Vec[4]

  Mat3* = Matrix[3, 3]
  Mat4* = Matrix[4, 4]

proc vec*[C: static int](value: float32): Vec[C] =
  for i in 0..<C:
    result[i] = value

proc `*=`*[C: static int](v: var Vec[C], scalar: float32) =
  for i in 0..<C:
    v[i] *= scalar

proc `*`*[C: static int](v: Vec[C], scalar: float32): Vec[C] =
  for i in 0..<C:
    result[i] = v[i] * scalar

proc `*`*[R, N, C: static int](
  a: Matrix[R, N],
  b: Matrix[N, C]
): Matrix[R, C] =
  for row in 0..<R:
    for col in 0..<C:
      for k in 0..<N:
        result[row][col] += a[row][k] * b[k][col]

proc identity*[C: static int](): Matrix[C, C] =
  for i in 0..<C:
    result[i][i] = 1.0

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

    if abs(a[pivot][col]) < 1e-7'f32:
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

template x*(v: Vec2 | Vec3 | Vec4): untyped =
  v[0]

template y*(v: Vec2 | Vec3 | Vec4): untyped =
  v[1]

template z*(v: Vec3 | Vec4): untyped =
  v[2]

template w*(v: Vec4): untyped =
  v[3]

proc vec2*(value: float32): Vec2 = vec[2](value)

proc vec3*(value: float32): Vec3 = vec[3](value)

const IdentityMatrix4* = identity[4]()

proc normalMatrix*(model: Mat4): Mat3 =
  let mat = model.inverse.transpose

  for row in 0..<3:
    for col in 0..<3:
      result[row][col] = mat[row][col]  
