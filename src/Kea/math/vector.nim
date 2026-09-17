import std/math, utils

type
  Vec*[C: static int] = array[C, float32]
  Vec1* = Vec[1]
  Vec2* = Vec[2]
  Vec3* = Vec[3]
  Vec4* = Vec[4]

template x*(v: Vec1 | Vec2 | Vec3 | Vec4): untyped =
  v[0]

template y*(v: Vec2 | Vec3 | Vec4): untyped =
  v[1]

template z*(v: Vec3 | Vec4): untyped =
  v[2]

template w*(v: Vec4): untyped =
  v[3]

proc hom*(v: Vec3, w: float32 = 1.0): Vec4 =
  [v.x, v.y, v.z, w]

proc xyz*(v: Vec4): Vec3 =
  [v.x, v.y, v.z]

proc xy*(v: Vec4 | Vec3): Vec2 =
  [v.x, v.y]

proc vec*[C: static int](value: float32): Vec[C] =
  for i in 0..<C:
    result[i] = value

proc vec2*(value: float32): Vec2 = vec[2](value)

proc vec3*(value: float32): Vec3 = vec[3](value)

proc vec4*(value: float32): Vec4 = vec[4](value)

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

proc `*`*[C: static int](a, b: Vec[C]): Vec[C] =
  for i in 0 ..< C:
    result[i] = a[i] * b[i]

proc `/`*[C: static int](a, b: Vec[C]): Vec[C] =
  for i in 0 ..< C:
    result[i] = a[i] / b[i]

proc `-`*[C: static int](scalar: float32, v: Vec[C]): Vec[C] =
  for i in 0 ..< C:
    result[i] = scalar - v[i]

proc `-`*[C: static int](v: Vec[C], scalar: float32): Vec[C] =
  for i in 0 ..< C:
    result[i] = v[i] - scalar

proc `+`*[C: static int](v: Vec[C], scalar: float32): Vec[C] =
  for i in 0 ..< C:
    result[i] = v[i] + scalar

proc `+`*[C: static int](scalar: float32, v: Vec[C]): Vec[C] =
  for i in 0 ..< C:
    result[i] = v[i] + scalar

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
  let
    axis = axis.normalize

    t = axis.perpendicular.normalize

    b = cross(t, axis)

    r = t * cos(phi) + b * sin(phi)

  axis * cos(theta) + r * sin(theta)

proc face*(normal, view: Vec3): Vec3 =
  if dot(normal, view) > 0.0: normal else: -normal

proc tangentToward*(normal, direction: Vec3): Vec3 =
  let
    tangent = direction - normal * dot(direction, normal)
    lengthSquared = dot(tangent, tangent)

  if lengthSquared > 1e-10'f:
    return tangent * lengthSquared.invsqrt

  let helper: Vec3 =
    if normal.z.abs < 0.999'f: [0.0'f, 0.0, 1.0]
    else: [0.0'f, 1.0, 0.0]

  cross(helper, normal).normalize

proc mix*[C: static int](a, b: Vec[C], t: float32): Vec[C] =
  a * (1.0'f - t) + b * t

proc clamp*[C: static int](v: Vec[C], min, max: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = v[i].clamp(min[i], max[i])

proc floor*[C: static int](v: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = floor(v[i])

proc max*[C: static int](a, b: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = max(a[i], b[i])

proc max*[C: static int](a: Vec[C], b: float32): Vec[C] =
  for i in 0..<C:
    result[i] = max(a[i], b)

proc min*[C: static int](a, b: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = min(a[i], b[i])

proc min*[C: static int](a: Vec[C], b: float32): Vec[C] =
  for i in 0..<C:
    result[i] = min(a[i], b)

proc abs*[C: static int](v: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = v[i].abs

proc sqrt*[C: static int](v: Vec[C]): Vec[C] =
  for i in 0..<C:
    result[i] = sqrt(v[i])
