import
  Kea/[
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
    resources
  ]

type
  PBRMaterial* = tuple[
    prevModel: Mat4 = Identity4,
    albedo: Vec3 = [1.0, 1.0, 1.0],
    roughness: float32 = 0.5,
    metallic: float32 = 0.0
  ]

  GBufferGlobals* = tuple[
    view: Mat4,
    proj: Mat4,
    jitter: Vec2,
    prevViewProjJitter: Mat4,
    eye: Vec3,
    light: RectLight,
    ltcInverseMatrixLut: Texture[Rgba32Float],
    ltcMagnitudeFresnelLut: Texture[Rg32Float]
  ]

  GBufferTarget* = ColorDepthTarget[tuple[
    analytic: Texture[Rgb32Float],
    position: Texture[Rgb32Float],
    motion: Texture[Rg32Float],
    normalRoughness: Texture[Rgba32Float],
    albedoMetallic: Texture[Rgba32Float]
  ]]

  GBufferRenderer*[M] =
    Renderer[GBufferGlobals, M, tuple[
      analytic: Vec3,
      position: Vec3,
      motion: Vec2,
      normalRoughness: Vec4,
      albedoMetallic: Vec4
    ]]

  PBRDraw* = proc(
    gbuffer: GBufferTarget,
    globals: GBufferGlobals
  ) {.closure}

  PBRSource* = concept source
    draws(source, Resources) is seq[PBRDraw]

  PBR* = ref object
    res: Resources

    pending*: seq[PBRDraw]

    frame: uint64
    prevViewProjJitter: Mat4
    history: Texture[Rgb32Float]

    ltcMagnitudeFresnelLut: Texture[Rg32Float]
    ltcInverseMatrixLut: Texture[Rgba32Float]

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

proc res*(pbr: PBR): Resources =
  pbr.res

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

    view = camera.view

    proj = camera.proj aspect

    jitter: Vec2 = block:
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

    gbuffer = pbr.res.target(
      key = "pbr/gbuffer",
      width = width,
      height = height,
      depth = true,
      attachments = (
        analytic: (format: Rgb32Float),
        position: (format: Rgb32Float),
        motion: (format: Rg32Float),
        normalRoughness: (format: Rgba32Float),
        albedoMetallic: (format: Rgba32Float)
      )
    )

  if pbr.frame == 0:
    pbr.prevViewProjJitter = proj * view

  gbuffer.clear()

  for draw in pbr.pending:
    draw(
      gbuffer,
      (
        view: view,
        proj: proj,
        jitter: jitter,
        prevViewProjJitter: pbr.prevViewProjJitter,
        eye: camera.positioned,
        light: light,
        ltcInverseMatrixLut: pbr.ltcInverseMatrixLut,
        ltcMagnitudeFresnelLut: pbr.ltcMagnitudeFresnelLut
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
      jitter: Vec2,
      currentColor: Texture[Rgb32Float],
      currentDepth: Texture[Depth24],
      historyValid: bool,
      history: Texture[Rgb32Float]
    ): tuple[pixel: Vec3] =
      let
        currentUv = uv + jitter
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
        jitter: jitter,
        currentColor: lit.atts.pixel,
        currentDepth: gbuffer.depth,
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

  # for item in pbr.items.values:
  #   item.prevModel = item.transform.model

  pbr.pending.setLen(0)

  pbr.prevViewProjJitter = proj * view
  pbr.history = taa.atts.pixel
  pbr.frame += 1
