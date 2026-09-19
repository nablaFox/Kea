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
    albedo: Vec3 = [1.0, 1.0, 1.0],
    roughness: float32 = 0.5,
    metallic: float32 = 0.0
  ]

  GBufferGlobals* = tuple[
    view: Mat4,
    proj: Mat4,
    eye: Vec3,
    light: RectLight,
    ltcInverseMatrixLut: Texture[Rgba32Float],
    ltcMagnitudeFresnelLut: Texture[Rg32Float]
  ]

  GBufferTarget* = ColorDepthTarget[tuple[
    analytic: Texture[Rgb32Float],
    position: Texture[Rgb32Float],
    normalRoughness: Texture[Rgba32Float],
    albedoMetallic: Texture[Rgba32Float]
  ]]

  GBufferRenderer*[M] =
    Renderer[GBufferGlobals, M, tuple[
      analytic: Vec3,
      position: Vec3,
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
  let (targetWidth, targetHeight) = target.size

  if targetWidth <= 0 or targetHeight <= 0:
    return

  let
    width = targetWidth * 2
    height = targetHeight * 2

    aspect = target.aspect

    view = camera.view

    proj = camera.proj aspect

    gbuffer = pbr.res.target(
      key = "pbr/gbuffer",
      width = width,
      height = height,
      depth = true,
      attachments = (
        analytic: (format: Rgb32Float),
        position: (format: Rgb32Float),
        normalRoughness: (format: Rgba32Float),
        albedoMetallic: (format: Rgba32Float)
      )
    )

  gbuffer.clear()

  for draw in pbr.pending:
    draw(
      gbuffer,
      (
        view: view,
        proj: proj,
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

  block:
    proc frag(
      uv: Vec2,
      color: Texture[Rgb32Float]
    ): tuple[pixel: Vec4] =
      let
        offset = [0.75'f, 0.75'f] / color.size
        resolved = (
          color.sample(uv + [-offset.x, -offset.y]).xyz +
          color.sample(uv + [ offset.x, -offset.y]).xyz +
          color.sample(uv + [-offset.x,  offset.y]).xyz +
          color.sample(uv + [ offset.x,  offset.y]).xyz
        ) * 0.25'f

      result.pixel = resolved
        .exponential
        .gamma
        .hom

    pbr.res.render(
      renderer = "pbr/tonemap-pass",
      target = target,
      frag = frag,
      globals = (
        color: lit.atts.pixel
      )
    )

  pbr.pending.setLen(0)
