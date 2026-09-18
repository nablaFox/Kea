import Kea/[resources, light, math, shader, texture], pbr

proc vert(
  vert: Vertex,
  model, prevModel: Mat4,
  nmat: Mat3,
  jitter: Vec2,
  view, proj, prevViewProjJitter: Mat4
): tuple[
  pos: Vec4,
  worldNormal: Vec3,
  worldPosition: Vec3,
  currClip: Vec4,
  prevClip: Vec4
] =
  let
    P = model * vert.position.hom

    currClip =
      proj *
      view *
      P

    prevClip =
      prevViewProjJitter *
      P

  result.pos = currClip + [
    2'f * jitter.x * currClip.w,
    2'f * jitter.y * currClip.w,
    0.0'f,
    0.0'f
  ]

  result.worldPosition = P.xyz
  result.worldNormal = nmat * vert.normal
  result.currClip = currClip
  result.prevClip = prevClip

proc frag(
  worldNormal: Vec3,
  worldPosition: Vec3,
  albedo: Vec3,
  roughness: float32,
  metallic: float32,
  eye: Vec3,
  light: RectLight,
  ltcInverseMatrixLut: Texture[Rgba32Float],
  ltcMagnitudeFresnelLut: Texture[Rg32Float],
  currClip, prevClip: Vec4
): tuple[
  analytic: Vec3,
  position: Vec3,
  motion: Vec2,
  normalRoughness: Vec4,
  albedoMetallic: Vec4
] =
  let
    P = worldPosition
    V = (eye - P).normalize
    N = worldNormal.normalize.face(V)

  result.position = worldPosition

  result.albedoMetallic = [albedo.x, albedo.y, albedo.z, metallic]

  result.normalRoughness = [N.x, N.y, N.z, roughness]

  result.motion = block:
    let
      currUv = (currClip.xy / currClip.w) * 0.5'f + 0.5'f
      prevUv = (prevClip.xy / prevClip.w) * 0.5'f + 0.5'f

    currUv - prevUv

  result.analytic = block:
    let
      size = ltcInverseMatrixLut.size
      x = roughness
      y = 1 - clamp(dot(N, V), 0, 1).sqrt
      uv = ([x, y] * (size - 1.0'f) + 0.5'f) / size

      shape = ltcInverseMatrixLut.sample(uv)
      terms = ltcMagnitudeFresnelLut.sample(uv).xy

    light.radiance(
      P, N, V,
      albedo,
      metallic,
      ltcShape = shape,
      ltcAmplitude = terms.x,
      ltcFresnelWeight = terms.y
    )

proc hooks*(res: Resources): GBUfferRenderer[PBRMaterial] =
  res.renderer(
    key = "pbr/gbuffer-pass",
    vert = vert,
    frag = frag,
    globals = GBufferGlobals
  )

# TODO
macro hooks*(
  res: Resources,
  deform: typed
): untyped =
  discard
