import 
  renderer, 
  mesh, 
  math, 
  ltc, 
  texture, 
  tonemap, 
  camera,
  target,
  colors,
  core,
  std/math

type 
  RectLight* = object
    position*: Vec3
    rotation*: Mat3 = Identity3
    width*: float32 = 1.0
    height*: float32 = 1.0
    radiance*: Vec3

  PBRMaterial* = tuple[
    albedo: Vec3 = [1.0, 1.0, 1.0],
    roughness: float32 = 0.5,
    metallic: float32 = 0.0,
  ]

  PBRGlobals* = tuple[
    view: Mat4,
    proj: Mat4,
    eye: Vec3,
    light: RectLight,
    ltcInverseMatrixLut: Texture[Rgba32Float],
    ltcMagnitudeFresnelLut: Texture[Rg32Float],
  ]

  PBRRenderer* = Renderer[
    PBRGlobals, 
    PBRMaterial,
    tuple[pixel: Vec4]
  ]

  Polygon = object
    vertices: array[5, Vec3]
    count: int

const 
  RedMaterial*: PBRMaterial = (
    albedo: [1.0, 0.0, 0.0],
    roughness: 0.5,
    metallic: 0.0
  )

  WhiteMaterial*: PBRMaterial = (
    albedo: [1.0, 1.0, 1.0],
    roughness: 0.5,
    metallic: 0.0
  )

proc corners(light: RectLight): array[4, Vec3] =
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

proc texelCenteredUv(size: Vec2, x, y: float32): Vec2 =
  ([x, y] * (size - 1.0'f) + 0.5'f) / size

proc vert*(
  vert: Vertex,
  model: Mat4,
  nmat: Mat3,
  view, proj: Mat4
): tuple[
  pos: Vec4,
  worldNormal: Vec3,
  worldPosition: Vec3
] = 
  let P = model * vert.position.hom

  result.pos = proj * view * P
  result.worldPosition = P.xyz
  result.worldNormal = nmat * vert.normal

proc frag*(
  worldNormal: Vec3,
  worldPosition: Vec3,

  albedo: Vec3,
  roughness: float32,
  metallic: float32,

  eye: Vec3,
  light: RectLight,
  ltcInverseMatrixLut: Texture[Rgba32Float],
  ltcMagnitudeFresnelLut: Texture[Rg32Float]
): tuple[pixel: Vec4] = 
  let 
    P = worldPosition
    V = (eye - P).normalize
    N = worldNormal.normalize.face(V)
    NdotV = dot(N, V)
  
  let
    uv = ltcInverseMatrixLut.size.texelCenteredUv(
      roughness,
      (1 - clamp(NdotV, 0, 1)).sqrt
    )
    
    shape = ltcInverseMatrixLut.sample(uv)
    terms = ltcMagnitudeFresnelLut.sample(uv).xy

  let
    corners = light.corners 
    specularIntegral = integrateRect(
      P, N, V,
      corners,
      [
        [shape.x, 0, shape.y],
        [0, 1, 0],
        [shape.z, 0, shape.w]
      ]
    )
    diffuseIntegral = integrateRect(
      P, N, V,
      corners,
      Identity3
    )

  let
    F0 = mix(vec3(0.04), albedo, metallic)
    specularScale = F0 * terms.x + (1 - F0) * terms.y
    specular = specularScale * specularIntegral
 
  let 
    diffuseColor = albedo * (1.0 - metallic)
    diffuse = diffuseColor * diffuseIntegral

  let 
    radiance = light.radiance * (specular + diffuse)
    ambient = 0.03 * albedo

  result.pixel = (ambient + radiance)
    .reinhard
    .gamma
    .hom

proc pbr*(
  kea: Kea,
  light: RectLight
): PBRRenderer = 
  let 
    ltcInverseMatrixLut = texture.new(
      ltc.InverseMatrixData,
      ltc.LutSize,
      ltc.LutSize,
      Rgba32Float,
      LinearTextureOptions
    )

    ltcMagnitudeFresnelLut = texture.new(
      ltc.MagnitudeFresnelData,
      ltc.LutSize,
      ltc.LutSize,
      Rg32Float,
      LinearTextureOptions
    )

  result = kea.renderer(
    vert = vert,
    frag = frag, 
    globals = (
      view: Identity4,
      proj: Identity4,
      eye: [0.0'f, 0.0, 0.0],
      light: light,
      ltcInverseMatrixLut: ltcInverseMatrixLut,
      ltcMagnitudeFresnelLut: ltcMagnitudeFresnelLut
    )
  )

  result.ltcInverseMatrixLut = ltcInverseMatrixLut

  result.ltcMagnitudeFresnelLut = ltcMagnitudeFresnelLut

proc render*(pbr: PBRRenderer, target: RenderTarget, camera: Camera) =
  pbr.eye = camera.positioned
  pbr.view = camera.view
  pbr.proj = camera.proj target.aspect

  pbr.render(target)
