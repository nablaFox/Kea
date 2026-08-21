import std/math

type 
  Vec*[C: static int] = array[C, float32]
  Matrix*[R, C: static int] = array[R, Vec[C]]

  Vec1* = Vec[1]
  Vec2* = Vec[2]
  Vec3* = Vec[3]
  Vec4* = Vec[4]

  Mat3* = Matrix[3, 3]
  Mat4* = Matrix[4, 4]

template x*(v: Vec1 | Vec2 | Vec3 | Vec4): untyped =
  v[0]

template r*(v: Vec1 | Vec2 | Vec3 | Vec4): untyped =
  v[0]

template y*(v: Vec2 | Vec3 | Vec4): untyped =
  v[1]

template g*(v: Vec2 | Vec3 | Vec4): untyped =
  v[1]

template z*(v: Vec3 | Vec4): untyped =
  v[2]

template b*(v: Vec3 | Vec4): untyped =
  v[2]

template w*(v: Vec4): untyped =
  v[3]

template a*(v: Vec4): untyped =
  v[3]

proc vec*[C: static int](value: float32): Vec[C] =
  for i in 0..<C:
    result[i] = value

proc `*`*[C: static int](v: Vec[C], scalar: float32): Vec[C] =
  for i in 0..<C:
    result[i] = v[i] * scalar

proc `*`*[C: static int](scalar: float32, v: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = v[i] * scalar

proc `*=`*[C: static int](v: var Vec[C], scalar: float32) =
  for i in 0..<C:
    v[i] *= scalar

proc `+`*[C: static int](a: Vec[C], b: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = a[i] + b[i]

proc `+=`*[C: static int](a: var Vec[C], b: Vec[C]) =
  for i in 0..<C:
    a[i] += b[i]

proc `-`*[C: static int](a: Vec[C], b: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = a[i] - b[i]

proc `-=`*[C: static int](a: var Vec[C], b: Vec[C]) =
  for i in 0..<C:
    a[i] -= b[i]

proc `-`*[C: static int](v: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = -v[i]

proc `/`*[C: static int](v: Vec[C], scalar: float32): Vec[C] =
  for i in 0..<C:
    result[i] = v[i] / scalar

proc `/=`*[C: static int](v: var Vec[C], scalar: float32) =
  for i in 0..<C:
    v[i] /= scalar

proc dot*[C: static int](a: Vec[C], b: Vec[C]): float32 =
  for i in 0..<C:
    result += a[i] * b[i]

proc normalize*[C: static int](v: Vec[C]): Vec[C] = 
  let length = sqrt(dot(v, v))

  if length > 1e-7'f: v / length else: vec[C](0.0)

proc length*[C: static int](v: Vec[C]): float32 =
  dot(v, v).sqrt

proc cross*(a, b: Vec3): Vec3 =
  [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ]

proc perpendicular*(v: Vec3): Vec3 =
  if v.x != 0 or v.y != 0: [-v.y, v.x, 0]
  else: [1'f, 0, 0]

proc reflect*(v, normal: Vec3): Vec3 =
  v - normal * 2.0 * dot(v, normal)

proc rotate*(axis: Vec3, theta: float32, phi: float32): Vec3 =
  let axis = axis.normalize

  let t = axis.perpendicular.normalize

  let b = cross(t, axis)

  let r = t * cos(phi) + b * sin(phi)

  axis * cos(theta) + r * sin(theta)

proc face*(normal, view: Vec3): Vec3 =
  if dot(normal, view) < 0.0: -normal else: normal 

proc hom*(v: Vec3, w: float32 = 1.0): Vec4 =
  [v.x, v.y, v.z, w]

proc xyz*(v: Vec4): Vec3 =
  [v.x, v.y, v.z]

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

proc vec2*(value: float32): Vec2 = vec[2](value)

proc vec3*(value: float32): Vec3 = vec[3](value)

proc vec4*(value: float32): Vec4 = vec[4](value)

const Identity3* = identity[3]()

const Identity4* = identity[4]()

proc normalMatrix*(model: Mat4): Mat3 =
  let mat = model.inverse.transpose

  for row in 0..<3:
    for col in 0..<3:
      result[row][col] = mat[row][col]  

proc pitch*(value: float32): Mat3 = 
  let cp = cos(value)
  let sp = sin(value)

  [
    [1.0, 0.0, 0.0],
    [0.0, cp, -sp],
    [0.0, sp, cp],
  ]

proc yaw*(value: float32): Mat3 =
  let cy = cos(value)
  let sy = sin(value)

  [
    [cy, 0.0, sy],
    [0.0, 1.0, 0.0],
    [-sy, 0.0, cy],
  ]

proc roll*(value: float32): Mat3 =
  let cr = cos(value)
  let sr = sin(value)

  [
    [cr, -sr, 0.0],
    [sr, cr, 0.0],
    [0.0, 0.0, 1.0],
  ]

proc lerp*(a, b: float32, t: float32): float32 =
  a + (b - a) * t

proc smoothstep*(a, b, x: float32): float32 =
  let t = ((x - a) / (b - a)).clamp(0.0, 1.0)
  t * t * (3.0 - 2.0 * t)
