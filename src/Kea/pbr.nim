import
  core,
  renderer,
  mesh,
  math,
  shader,
  ltc,
  texture,
  tonemap,
  camera,
  target,
  transform,
  item,
  colors,
  light,
  resources,
  std/[tables, sugar]

type
  PBRMaterial = tuple[
    prevModel: Mat4,
    albedo: Vec3 = [1.0, 1.0, 1.0],
    roughness: float32 = 0.5,
    metallic: float32 = 0.0
  ]

  PBRItem* = ref object
    mesh*: Mesh
    topology*: Topology
    transform*: Transform

    albedo*: Vec3 = [1.0, 1.0, 1.0]
    roughness*: float32 = 0.5
    metallic*: float32 = 0.0

    prevModel: Mat4

  PBR* = ref object
    res: Resources

    items: OrderedTable[string, PBRItem]

    frame: uint64
    prevViewProj: Mat4
    historyWidth, historyHeight: int
    history: Texture[Rgb32Float]

    ltcMagnitudeFresnelLut: Texture[Rg32Float]
    ltcInverseMatrixLut: Texture[Rgba32Float]

const
  Red* = (
    albedo: [1.0, 0.0, 0.0],
    roughness: 0.5,
    metallic: 0.0
  )

  White* = (
    albedo: [1.0, 1.0, 1.0],
    roughness: 0.5,
    metallic: 0.0
  )

proc new*(res: Resources): PBR =
  let
    ltcInverseMatrixLut = res.texture(
      data = ltc.InverseMatrixData,
      key = "pbr/ltc-inverse-matrix-lut",
      ltc.LutSize,
      ltc.LutSize,
      Rgba32Float,
      LinearTextureOptions
    )

    ltcMagnitudeFresnelLut = res.texture(
      data = ltc.MagnitudeFresnelData,
      key = "pbr/ltc-magnitude-fresnel-lut",
      ltc.LutSize,
      ltc.LutSize,
      Rg32Float,
      LinearTextureOptions
    )

  PBR(
    res: res,
    ltcInverseMatrixLut: ltcInverseMatrixLut,
    ltcMagnitudeFresnelLut: ltcMagnitudeFresnelLut
  )

proc render*(
  pbr: PBR,
  target: RenderTarget,
  camera: Camera,
  light: RectLight
) =
  let (width, height) = target.size

  if width <= 0 or height <= 0:
    return

  let
    aspect = target.aspect

    items = collect:
      for source in pbr.items.values:
        RenderItem[PBRMaterial](
          renderable: Renderable(
            mesh: source.mesh,
            topology: source.topology,
            transform: source.transform
          ),
          material: (
            prevModel: source.prevModel,
            albedo: source.albedo,
            roughness: source.roughness,
            metallic: source.metallic
          )
        )

    view = camera.view
    proj = camera.proj aspect

  if pbr.frame == 0:
    pbr.prevViewProj = proj * view

  let gbuffer = block:
    proc vert(
      vert: Vertex,
      model, prevModel: Mat4,
      nmat: Mat3,
      view, proj, prevViewProj: Mat4
    ): tuple[
      pos: Vec4,
      worldNormal: Vec3,
      worldPosition: Vec3,
      currClip: Vec4,
      prevClip: Vec4
    ] =
      let 
        P = model * vert.position.hom
        pos = proj * view * P

      result.pos = pos
      result.worldPosition = P.xyz
      result.worldNormal = nmat * vert.normal
      result.currClip = pos
      result.prevClip = prevViewProj * prevModel * vert.position.hom

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
      normal: Vec3,
      albedo: Vec3,
      roughness: float32,
      metallic: float32,
      motion: Vec2
    ] =
      proc texelCenteredUv(size: Vec2, x, y: float32): Vec2 =
        ([x, y] * (size - 1.0'f) + 0.5'f) / size

      # TODO: add support for block expressions
      let
        P = worldPosition
        V = (eye - P).normalize
        N = worldNormal.normalize.face(V)
        NdotV = dot(N, V)

        uv = ltcInverseMatrixLut.size.texelCenteredUv(
          roughness,
          (1 - clamp(NdotV, 0, 1)).sqrt
        )

        shape = ltcInverseMatrixLut.sample(uv)
        terms = ltcMagnitudeFresnelLut.sample(uv).xy

        currUv = (currClip.xy / currClip.w) * 0.5'f + 0.5'f
        prevUv = (prevClip.xy / prevClip.w) * 0.5'f + 0.5'f

      result.position = worldPosition
      result.normal = worldNormal
      result.albedo = albedo
      result.roughness = roughness
      result.metallic = metallic
      result.motion = currUv - prevUv
      result.analytic = light.radiance(
        P, N, V,
        albedo,
        metallic,
        ltcShape = shape,
        ltcAmplitude = terms.x,
        ltcFresnelWeight = terms.y
      )

    pbr.res.render(
      renderer = "pbr/geometry-pass",
      target = "pbr/gbuffer",
      width = width,
      height = height,
      vert = vert,
      frag = frag,
      items = items,
      globals = (
        view: view,
        proj: proj,
        eye: camera.positioned,
        light: light,
        ltcInverseMatrixLut: pbr.ltcInverseMatrixLut,
        ltcMagnitudeFresnelLut: pbr.ltcMagnitudeFresnelLut,
        prevViewProj: pbr.prevViewProj
      )
    )

  let shadows = block:
    proc frag(uv: Vec2): tuple[
      unshadowed: Vec3,
      shadowed: Vec3
    ] =
      # TODO
      result.unshadowed = [1.0, 1.0, 1.0]
      result.shadowed = [1.0, 1.0, 1.0]

    pbr.res.render(
      renderer = "pbr/shadow-pass",
      target = "pbr/shadows",
      width = width,
      height = height,
      frag = frag,
      # TODO: globals from gbuffer atts + bvh + triangles
      globals = ()
    )

  let filtered = block:
    proc frag(
      unshadowed: Texture[Rgb32Float],
      shadowed: Texture[Rgb32Float],
      uv: Vec2
    ): tuple[
      unshadowed: Vec3,
      shadowed: Vec3
    ] =
      # TODO
      result.unshadowed = unshadowed.sample(uv).xyz
      result.shadowed = shadowed.sample(uv).xyz

    pbr.res.render(
      renderer = "pbr/shadow-denoise-pass",
      target = "pbr/filtered",
      width = width,
      height = height,
      frag = frag,
      globals = (
        unshadowed: shadows.atts.unshadowed,
        shadowed: shadows.atts.shadowed
      )
    )

  let lit = block:
    proc frag(
      uv: Vec2,
      analytic: Texture[Rgb32Float],
      unshadowed: Texture[Rgb32Float],
      shadowed: Texture[Rgb32Float]
    ): tuple[pixel: Vec3] =
      let 
        U = analytic.sample(uv).xyz
        S = shadowed.sample(uv).xyz
        W = S / unshadowed.sample(uv).xyz 

      result.pixel = U * W

    pbr.res.render(
      renderer = "pbr/lit-pass",
      target = "pbr/lit",
      width = width,
      height = height,
      frag = frag,
      globals = (
        analytic: gbuffer.atts.analytic,
        unshadowed: filtered.atts.unshadowed,
        shadowed: filtered.atts.shadowed
      )
    )

  let taa = block:
    proc frag(
      uv: Vec2,
      historyValid: bool,
      current: Texture[Rgb32Float],
      motion: Texture[Rg32Float],
      history: Texture[Rgb32Float]
    ): tuple[pixel: Vec3] = 
      result.pixel = 
        if not historyValid:
          current.sample(uv).xyz
        else:
          # TODO
          current.sample(uv).xyz

    let historyValid =
      pbr.history != nil and
      pbr.history.width == width.int and
      pbr.history.height == height.int

    pbr.res.render(
      renderer = "pbr/taa-pass",
      target = "pbr/history/" & $(pbr.frame mod 2),
      width = width,
      height = height,
      frag = frag,
      colorOptions = LinearTextureOptions,
      globals = (
        current: lit.atts.pixel,
        motion: gbuffer.atts.motion,
        historyValid: historyValid,
        history: 
          if historyValid: pbr.history
          else: lit.atts.pixel,
      )
    )

  block:
    proc frag(
      uv: Vec2,
      taa: Texture[Rgb32Float]
    ): tuple[pixel: Vec4] =
      result.pixel = taa
        .sample(uv)
        .xyz
        .gamma
        .hom

    pbr.res.render(
      renderer = "pbr/tonemap-pass",
      target = target,
      frag = frag,
      globals = (
        taa: taa.atts.pixel
      )
    )

  for item in pbr.items.values:
    item.prevModel = item.transform.model

  pbr.prevViewProj = proj * view
  pbr.historyWidth = width
  pbr.historyHeight = height
  pbr.history = taa.atts.pixel
  pbr.frame += 1

proc add*(
  pbr: PBR,
  key: string,
  mesh: Mesh,
  transform: Transform,
  topology: Topology = Triangles,
  albedo: Vec3 = [1.0, 1.0, 1.0],
  roughness: float32 = 0.5,
  metallic: float32 = 0.0
): PBRItem =
  result = PBRItem(
    mesh: mesh,
    topology: topology,
    transform: transform,
    albedo: albedo,
    roughness: roughness,
    metallic: metallic,
    prevModel: transform.model
  )

  pbr.items[key] = result

proc add*(
  pbr: PBR,
  key: string,
  mesh: Mesh,
  albedo: Vec3 = [1.0, 1.0, 1.0],
  roughness: float32 = 0.5,
  metallic: float32 = 0.0,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0),
  topology: Topology = Triangles
): PBRItem =
  pbr.add(
    key,
    mesh,
    transform.new(
      x = x,
      y = y,
      z = z,
      yaw = yaw,
      pitch = pitch,
      roll = roll,
      scale = scale,
    ),
    topology = topology,
    albedo = albedo,
    roughness = roughness,
    metallic = metallic
  )

proc remove*(
  pbr: PBR,
  key: string
) =
  pbr.items.del(key)

proc transform*(item: PBRItem): var Transform =
  item.transform

proc position*(item: PBRItem): var Vec3 =
  item.transform.position

proc scale*(item: PBRItem): var Vec3 =
  item.transform.scale

proc rotation*(item: PBRItem): var Mat3 =
  item.transform.rotation

proc positioned*(item: PBRItem): Vec3 =
  let transform = item.transform
  transform.position

proc scaled*(item: PBRItem): Vec3 =
  let transform = item.transform
  transform.scale

proc rotated*(item: PBRItem): Mat3 =
  let transform = item.transform
  transform.rotation
