type 
  Vec*[C: static int] = array[C, float32]
  Matrix*[R, C: static int] = array[R, Vec[C]]

  Vec2* = Vec[2]
  Vec3* = Vec[3]
  Vec4* = Vec[4]

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

proc transpose*[R, C: static int](m: Matrix[R, C]): Matrix[C, R] =
  for row in 0..<R:
    for col in 0..<C:
      result[col][row] = m[row][col]

proc identity*[C: static int](): Matrix[C, C] =
  for i in 0..<C:
    result[i][i] = 1.0

template x*(v: Vec2 | Vec3): untyped =
  v[0]

template y*(v: Vec2 | Vec3): untyped =
  v[1]

template z*(v: Vec3): untyped =
  v[2]

template w*(v: Vec4): untyped =
  v[3]

proc vec2*(value: float32): Vec2 = vec[2](value)

proc vec3*(value: float32): Vec3 = vec[3](value)

const IdentityMatrix4* = identity[4]()
