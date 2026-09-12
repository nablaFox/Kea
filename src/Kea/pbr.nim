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
    albedo: Vec3 = [1.0, 1.0, 1.0],
    roughness: float32 = 0.5,
    metallic: float32 = 0.0
  ]

  PBRItem* = ref object
    renderable*: Renderable
    material*: PBRMaterial

  PBR* = ref object
    res: Resources
    items: OrderedTable[string, PBRItem]
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
      ltc.LutSize,
      ltc.LutSize,
      Rgba32Float,
      LinearTextureOptions
    )

    ltcMagnitudeFresnelLut = res.texture(
      data = ltc.MagnitudeFresnelData,
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
  let
    (width, height) = target.size

    aspect = target.aspect

    items = collect:
      for source in pbr.items.values:
        RenderItem[PBRMaterial](
          renderable: source.renderable,
          material: source.material
        )

  let gbuffer = block:
    proc vert(
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

    proc frag(
      worldNormal: Vec3,
      worldPosition: Vec3,
      albedo: Vec3,
      roughness: float32,
      metallic: float32,
      eye: Vec3,
      light: RectLight,
      ltcInverseMatrixLut: Texture[Rgba32Float],
      ltcMagnitudeFresnelLut: Texture[Rg32Float]
    ): tuple[
      unshadowed: Vec3,
      position: Vec3,
      normal: Vec3,
      albedo: Vec3,
      roughness: float32,
      metallic: float32
    ] =
      proc texelCenteredUv(size: Vec2, x, y: float32): Vec2 =
        ([x, y] * (size - 1.0'f) + 0.5'f) / size

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

      result.position = worldPosition
      result.normal = worldNormal
      result.albedo = albedo
      result.roughness = roughness
      result.metallic = metallic
      result.unshadowed = light.radiance(
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
        view: camera.view,
        proj: camera.proj aspect,
        eye: camera.positioned,
        light: light,
        ltcInverseMatrixLut: pbr.ltcInverseMatrixLut,
        ltcMagnitudeFresnelLut: pbr.ltcMagnitudeFresnelLut
      )
    )

  let shadows = block:
    proc frag(uv: Vec2): tuple[
      UN: Vec3,
      SN: Vec3
    ] = 
      result.UN = [0.0, 0.0, 0.0]
      result.SN = [0.0, 0.0, 0.0]

    pbr.res.render(
      renderer = "pbr/shadow-pass",
      target = "pbr/shadows",
      width = width,
      height = height,
      frag = frag,
      # TODO: globals from gbuffer atts
      globals = ()
    )

  let filtered = block:
    proc frag(uv: Vec2): tuple[
      UN: Vec3,
      SN: Vec3
    ] = 
      result.UN = [0.0, 0.0, 0.0]
      result.SN = [0.0, 0.0, 0.0]

    pbr.res.render(
      renderer = "pbr/shadow-denoise-pass",
      target = "pbr/filtered",
      width = width,
      height = height,
      frag = frag,
      # TODO: globals from shadows atts
      globals = ()
    )

  block:
    proc frag(
      uv: Vec2,
      unshadowed: Texture[Rgb32Float]
    ): tuple[pixel: Vec4] =
      result.pixel = unshadowed
        .sample(uv)
        .xyz
        .gamma
        .hom

    pbr.res.render(
      renderer = "pbr/compose-pass",
      target,
      frag = frag,
      # TODO: globals from gbuffer and filtered atts
      globals = (
        unshadowed: gbuffer.atts.unshadowed
      )
    )

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
    renderable: Renderable(
      mesh: mesh,
      topology: topology,
      transform: transform
    ),
    material: (
      albedo: albedo,
      roughness: roughness,
      metallic: metallic
    )
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
  item.renderable.transform

proc position*(item: PBRItem): var Vec3 =
  item.renderable.position

proc positioned*(item: PBRItem): Vec3 =
  item.renderable.positioned

proc scale*(item: PBRItem): var Vec3 =
  item.renderable.scale

proc scaled*(item: PBRItem): Vec3 =
  item.renderable.scaled

proc rotation*(item: PBRItem): var Mat3 =
  item.renderable.rotation

proc rotated*(item: PBRItem): Mat3 =
  item.renderable.rotated
