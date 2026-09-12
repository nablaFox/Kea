import math

type
  RectLight* = object
    position*: Vec3
    rotation*: Mat3 = Identity3
    width*: float32 = 1.0
    height*: float32 = 1.0
    radiance*: Vec3

  Polygon = object
    vertices: array[5, Vec3]
    count: int

proc corners*(light: RectLight): array[4, Vec3] =
  let
    right = light.rotation * [-1.0'f, 0.0, 0.0]
    up = light.rotation * [0.0'f, 1.0, 0.0]
    x = right * light.width / 2.0
    y = up * light.height / 2.0
    center = light.position

  [
    center - y - x,
    center + x - y,
    center + x + y,
    center - x + y
  ]

proc radiance*(
  light: RectLight,
  P, N, V: Vec3,
  albedo: Vec3,
  metallic: float32,
  ltcShape: Vec4,
  ltcAmplitude: float32,
  ltcFresnelWeight: float32
): Vec3 =
  # TODO: add shader support for defining polygon here

  proc clipAgainstHorizon(vertices: array[4, Vec3]): Polygon =
    for i in 0 ..< 4:
      let
        a = vertices[i]
        b = vertices[(i + 1) mod 4]
        aInside = a.z > 0
        bInside = b.z > 0

      if aInside:
        result.vertices[result.count] = a
        result.count += 1

      if aInside != bInside:
        let t = a.z / (a.z - b.z)
        result.vertices[result.count] = mix(a, b, t)
        result.count += 1

  proc edgeIntegral(a, b: Vec3): float32 =
    let
      x = dot(a, b)
      y = x.abs
      numerator = 0.8543985'f + (0.4965155'f + 0.0145206'f * y) * y
      denominator = 3.4175940'f + (4.1616724'f + y) * y

    var weight = numerator / denominator

    if x <= 0:
      weight = 0.5'f * max(1.0'f - x * x, 1e-7'f).invsqrt - weight

    cross(a, b).z * weight

  proc integrateRect(
    P, N, V: Vec3,
    corners: array[4, Vec3],
    inverseLtc: Mat3
  ): float32 =
    let
      tangent = N.tangentToward(V)
      bitangent = cross(N, tangent)
      basis = [tangent, bitangent, N]
      transform = inverseLtc * basis.transpose

    var cosineCorners: array[4, Vec3]

    for i in 0 ..< 4:
      cosineCorners[i] = transform * (corners[i] - P)

    var polygon = cosineCorners.clipAgainstHorizon

    if polygon.count < 3:
      return 0.0'f

    for i in 0 ..< polygon.count:
      polygon.vertices[i] = polygon.vertices[i].normalize

    var integral = 0.0'f

    for i in 0 ..< polygon.count:
      let
        a = polygon.vertices[i]
        b = polygon.vertices[(i + 1) mod polygon.count]

      integral += edgeIntegral(a, b)

    max(0.0'f, integral)

  let
    corners = light.corners

    specularIntegral = integrateRect(
      P, N, V,
      corners,
      [
        [ltcShape.x, 0, ltcShape.y],
        [0, 1, 0],
        [ltcShape.z, 0, ltcShape.w]
      ]
    )

    diffuseIntegral = integrateRect(
      P, N, V,
      corners,
      Identity3
    )

  let
    # TODO: derive F0 from ior
    F0 = mix(vec3(0.04), albedo, metallic)
    specularScale = F0 * ltcAmplitude + (1 - F0) * ltcFresnelWeight
    specular = specularScale * specularIntegral

  let
    diffuseColor = albedo * (1.0 - metallic)
    diffuse = diffuseColor * diffuseIntegral

  light.radiance * (specular + diffuse)
