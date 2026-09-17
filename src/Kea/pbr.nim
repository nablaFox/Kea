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
    prevViewProjJitter: Mat4
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

    jitterUv: Vec2 = block:
      proc halton(i, base: int): float32 =
        var
          f = 1.0'f
          r = 0.0'f
          x = i

        while x > 0:
          f /= base.float32
          r += f * (x mod base).float32
          x = x div base

        r

      let i = int(pbr.frame mod 16) + 1

      [
        (halton(i, 2) - 0.5'f) / width.float32,
        (halton(i, 3) - 0.5'f) / height.float32
      ]

    jitter = [2'f * jitterUv.x, 2'f * jitterUv.y, 0'f].transMatrix

  if pbr.frame == 0:
    pbr.prevViewProjJitter = proj * view

  let gbuffer = block:
    proc vert(
      vert: Vertex,
      model, prevModel: Mat4,
      nmat: Mat3,
      view, proj, prevViewProjJitter, jitter: Mat4
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
          prevModel *
          vert.position.hom

      result.pos = jitter * currClip
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
      albedoMetallic: Vec4,
      depth: float32
    ] =
      let
        P = worldPosition
        V = (eye - P).normalize
        N = worldNormal.normalize.face(V)

      result.position = worldPosition

      result.albedoMetallic = [albedo.x, albedo.y, albedo.z, metallic]

      result.normalRoughness = [N.x, N.y, N.z, roughness]

      result.depth = currClip.w

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
        jitter: jitter,
        eye: camera.positioned,
        light: light,
        ltcInverseMatrixLut: pbr.ltcInverseMatrixLut,
        ltcMagnitudeFresnelLut: pbr.ltcMagnitudeFresnelLut,
        prevViewProjJitter: pbr.prevViewProjJitter
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
        W = shadowed.sample(uv).xyz /
          unshadowed.sample(uv).xyz

      result.pixel = U * W

    pbr.res.render(
      renderer = "pbr/lit-pass",
      target = "pbr/lit",
      width = width,
      height = height,
      frag = frag,
      colorOptions = (pixel: LinearTextureOptions),
      globals = (
        analytic: gbuffer.atts.analytic,
        unshadowed: filtered.atts.unshadowed,
        shadowed: filtered.atts.shadowed
      )
    )

  let taa = block:
    proc frag(
      uv: Vec2,
      motion: Texture[Rg32Float],
      jitterUv: Vec2,
      currentColor: Texture[Rgb32Float],
      currentDepth: Texture[R32Float],
      historyValid: bool,
      history: Texture[Rgb32Float]
    ): tuple[pixel: Vec3] =
      let 
        currentUv = uv + jitterUv
        current = currentColor.sample(currentUv).xyz

      if not historyValid:
        result.pixel = current
        return

      # velocity dilation
      let velocity = block:
        let
          size = currentDepth.size
          center = (currentUv * size).floor

        var 
          z = 1e30'f
          p = center

        # TODO: add support for iterators
        for x in -1 .. 1:
          for y in -1 .. 1:
            let 
              q = clamp(
                center + [x.float32, y.float32],
                [0.0'f, 0.0],
                size - 1'f
              )

              depth = currentDepth.texelFetch(q, 0).x

            if depth > 0'f and depth < z:
              z = depth
              p = q

        motion.texelFetch(p, 0).xy

      let historyUv = uv - velocity

      if historyUv.x < 0 or historyUv.x > 1 or
          historyUv.y < 0 or historyUv.y > 1:
        result.pixel = current
        return 

      # sd and mean in YCoCg space over 3x3 neighb.
      let (sd, mean) = block:
        let
          size = currentColor.size
          center = (currentUv * size).floor

        var
          mean = [0.0'f, 0.0, 0.0]
          m2 = [0.0'f, 0.0, 0.0]

        # TODO: add support for iterators
        for x in -1 .. 1:
          for y in -1 .. 1:
            let
              q = clamp(
                center + [x.float32, y.float32],
                [0.0'f, 0.0],
                size - 1'f
              )

              color = currentColor
                .texelFetch(q, 0)
                .xyz
                .rgbToYCoCg

            mean += color
            m2 += color * color 

        mean /= 9'f
        m2 /= 9'f

        (
          sd: max(m2 - mean * mean, 0).sqrt,
          mean: mean
        )

      # variance direction-preserving clipping
      let clipped = block:
        let
          gamma = 1.5'f
          extent = gamma * sd + vec3(1e-5'f)
          H = history.sample(historyUv).xyz.rgbToYCoCg
          delta = H - mean

          distance = min(
            extent.x / max(abs(delta.x), 1e-5'f),
            min(
              extent.y / max(abs(delta.y), 1e-5'f),
              extent.z / max(abs(delta.z), 1e-5'f)
            )
          )

        mean + delta * min(distance, 1'f)

      let color = current.rgbToYCoCg

      # adaptive temporal blend
      let alpha = block:
        let
          d = clamp(
            abs(color.x - clipped.x) /
              max(max(color.x, clipped.x), 0.2'f),
            0'f,
            1'f
          )

          weight = (1 - d) * (1 - d)

        lerp(0.85, 0.95, weight)

      result.pixel = ((1 - alpha) * color + alpha * clipped)
        .ycocgToRgb

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
      colorOptions = (pixel: LinearTextureOptions),
      globals = (
        motion: gbuffer.atts.motion,
        jitterUv: jitterUv,
        currentColor: lit.atts.pixel,
        currentDepth: gbuffer.atts.depth,
        historyValid: historyValid,
        history:
          if historyValid: pbr.history
          else: lit.atts.pixel
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
        .exponential
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

  pbr.prevViewProjJitter = proj * view
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
