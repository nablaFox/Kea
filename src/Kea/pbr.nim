import 
  renderer, 
  mesh, 
  math, 
  ltc, 
  texture, 
  tonemap, 
  shader, 
  camera,
  target,
  colors,
  core

type 
  RectLight* = object
    position*: Vec3
    rotation*: Mat3 = Identity3
    width*: float32 = 1.0
    height*: float32 = 1.0
    radiance*: Vec3

  PBRMaterial* = tuple[
    albedo: Vec3,
    roughness: float32,
    metallic: float32,
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

const 
  Red*: PBRMaterial = (
    albedo: [1.0, 0.0, 0.0],
    roughness: 0.5,
    metallic: 0.0
  )

  White*: PBRMaterial = (
    albedo: [1.0, 1.0, 1.0],
    roughness: 0.5,
    metallic: 0.0
  )

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
  let P = worldPosition

  let V = (eye - P).normalize

  let N = worldNormal.normalize.face(-V)

  let ambient = 0.03 * albedo

  # TODO: compute radiance
  let radiance = [0.0'f, 0.0, 0.0]

  result.pixel = (ambient + radiance)
    .reinhard
    .sRGB
    .hom

proc pbr*(
  kea: Kea,
  position: Vec3 = [0.0, 0.0, 0.0],
  radiance: Vec3 = [1.0, 1.0, 1.0],
  rotation: Mat3 = Identity3,
  width: float32 = 1.0,
  height: float32 = 1.0,
): PBRRenderer = 
  let ltcInverseMatrixLut = texture.new(
    ltc.InverseMatrixData,
    ltc.LutSize,
    ltc.LutSize,
    Rgba32Float,
    LinearTextureOptions
  )

  let ltcMagnitudeFresnelLut = texture.new(
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
      light: RectLight(
        position: position,
        rotation: rotation,
        width: width,
        height: height,
        radiance: radiance
      ),
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
