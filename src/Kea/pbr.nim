import 
  renderer, 
  mesh, 
  math, 
  ltc, 
  texture, 
  tonemap, 
  shader, 
  colors

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
    tuple[color: Vec4]
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

proc radiance*(
  light: RectLight,
  P, N, V: Vec3,
  albedo: Vec3,
  roughness: float32,
  metallic: float32,
  ltcInverseMatrixLut: Texture[Rgba32Float],
  ltcMagnitudeFresnelLut: Texture[Rg32Float],
): Color = discard

proc vert*(
  vertex: Vertex,
  model: Mat4,
  nmat: Mat3,
  material: PBRMaterial,
  globals: PBRGlobals,
  position: var Vec4,
  output: var tuple[
    worldNormal: Vec3,
    worldPosition: Vec3
  ]
) = 
  let P = model * vertex.position.hom

  position = globals.proj * globals.view * P
  output.worldPosition = P.xyz
  output.worldNormal = nmat * vertex.normal

proc frag*(
  material: PBRMaterial,
  globals: PBRGlobals,

  input: tuple[
    worldNormal: Vec3,
    worldPosition: Vec3,
  ],

  atts: var tuple[color: Vec4]
) = 
  let P = input.worldPosition

  let V = (globals.eye - P).normalize

  let N = input
    .worldNormal
    .normalize
    .face(-V)

  let ambient = 0.03 * material.albedo

  let radiance = globals.light.radiance(
    P, N, V,
    material.albedo,
    material.roughness,
    material.metallic,
    globals.ltcInverseMatrixLut,
    globals.ltcMagnitudeFresnelLut
  )

  atts.color = (ambient + radiance)
    .reinhard
    .sRGB
    .hom

proc new*(storage: MeshStorage): PBRRenderer = 
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

  result = renderer.new(
    storage,
    vert,
    frag, 
  )

  result.ltcInverseMatrixLut = ltcInverseMatrixLut

  result.ltcMagnitudeFresnelLut = ltcMagnitudeFresnelLut
