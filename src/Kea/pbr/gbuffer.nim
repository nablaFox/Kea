import
  Kea/[resources, light, math, shader, texture],
  std/[macros, genasts, hashes],
  pbr

type
  Vert* = object
    position*: Vec3
    normal*: Vec3
    uv*: Vec2

  Frag* = object
    worldNormal*: Vec3
    worldPosition*: Vec3
    albedo*: Vec3
    roughness*: float32
    metallic*: float32
    view*: Vec3
    uv*: Vec2

proc liftLambda(hook: NimNode, name: string, definitions: NimNode): NimNode =
  if hook.kind != nnkLambda:
    return hook

  result = genSym(nskProc, name)

  let definition = newNimNode(nnkProcDef, hook)

  for child in hook:
    definition.add child.copyNimTree

  definition[0] = result
  definitions.add definition

macro renderer*(
  res: Resources,
  deform: typed,
  surface: typed
): untyped =
  let hookDefs = newStmtList()

  let
    deformHook = liftLambda(deform, "keaDeformHook", hookDefs)
    surfaceHook = liftLambda(surface, "keaSurfaceHook", hookDefs)

  result = genAst(
    res, hookDefs, deform = deformHook, surface = surfaceHook,
    result = ident"result",
    vert = ident"vert",
    model = ident"model", nmat = ident"nmat",
    view = ident"view", proj = ident"proj",
    worldNormal = ident"worldNormal", worldPosition = ident"worldPosition",
    albedo = ident"albedo", roughness = ident"roughness",
    metallic = ident"metallic", eye = ident"eye", light = ident"light",
    ltcInverseMatrixLut = ident"ltcInverseMatrixLut",
    ltcMagnitudeFresnelLut = ident"ltcMagnitudeFresnelLut",
    deformed = ident"deformed", surf = ident"surf",
    surfaceNormal = ident"surfaceNormal",
    P = ident"P", V = ident"V", N = ident"N",
    lutSize = ident"lutSize", x = ident"x", y = ident"y", uv = ident"uv",
    shape = ident"shape", terms = ident"terms"
  ):
    block:
      hookDefs

      proc vert(
        vert: Vertex,
        model: Mat4, nmat: Mat3,
        view, proj: Mat4
      ): tuple[
        pos: Vec4,
        uv: Vec2,
        worldNormal: Vec3,
        worldPosition: Vec3
      ] =
        let
          deformed = deform(
            Vert(
              position: vert.position,
              normal: vert.normal,
              uv: vert.uv
            )
          )

          P = model * deformed.position.hom

        result.pos = proj * view * P
        result.worldPosition = P.xyz
        result.worldNormal = nmat * deformed.normal
        result.uv = deformed.uv

      proc frag(
        worldNormal: Vec3,
        worldPosition: Vec3,
        uv: Vec2,
        albedo: Vec3,
        roughness: float32,
        metallic: float32,
        eye: Vec3,
        light: RectLight,
        ltcInverseMatrixLut: Texture[Rgba32Float],
        ltcMagnitudeFresnelLut: Texture[Rg32Float]
      ): tuple[
        analytic: Vec3,
        position: Vec3,
        normalRoughness: Vec4,
        albedoMetallic: Vec4
      ] =
        let
          P = worldPosition
          V = (eye - P).normalize
          N = worldNormal.normalize

          surf = surface(
            Frag(
              worldNormal: N,
              worldPosition: P,
              albedo: albedo,
              roughness: roughness,
              metallic: metallic,
              view: V,
              uv: uv
            )
          )

          surfaceNormal = surf.worldNormal.normalize

        result.position = worldPosition

        result.albedoMetallic = surf
          .albedo
          .hom(surf.metallic)

        result.normalRoughness = surfaceNormal
          .hom(surf.roughness)

        result.analytic = block:
          let
            lutSize = ltcInverseMatrixLut.size
            x = surf.roughness
            y = 1 - clamp(dot(surfaceNormal, V), 0, 1).sqrt
            uv = ([x, y] * (lutSize - 1.0'f) + 0.5'f) / lutSize

            shape = ltcInverseMatrixLut.sample(uv)
            terms = ltcMagnitudeFresnelLut.sample(uv).xy

          light.radiance(
            P, surfaceNormal, V,
            surf.albedo,
            surf.metallic,
            ltcShape = shape,
            ltcAmplitude = terms.x,
            ltcFresnelWeight = terms.y
          )

      const key = "pbr/gbuffer:" & $hash(
        vertGlsl(vert) & "\0" & fragGlsl(vert, frag)
      )

      res.renderer(
        key = key,
        vert = vert,
        frag = frag,
        globals = GBufferGlobals
      )

proc renderer*(res: Resources): GBUfferRenderer[PBRMaterial] =
  res.renderer(
    # deform shader
    deform = proc(vert: Vert): Vert =
      vert,

    # surface shader
    surface = proc(frag: Frag): Frag =
      frag
  )

macro hooks*(
  res: Resources,
  albedo: typed = nil,
  roughness: typed = nil,
  metallic: typed = nil,
  position: typed = nil,
  normal: typed = nil,
  worldNormal: typed = nil
): untyped =
  let
    hookDefs = newStmtList()
    deformBody = newStmtList()
    surfaceBody = newStmtList()
    deformCombined = genSym(nskProc, "keaDeformCombined")
    surfaceCombined = genSym(nskProc, "keaSurfaceCombined")

  proc addOverride(
    body: NimNode, 
    field: string, 
    hook: NimNode
  ) =
    if hook.kind == nnkNilLit:
      return

    let callable = liftLambda(hook, "keaHook_" & field, hookDefs)

    body.add newAssignment(
      newDotExpr(ident"result", ident(field)),
      newCall(callable, ident"value")
    )

  deformBody.addOverride("position", position)
  deformBody.addOverride("normal", normal)
  surfaceBody.addOverride("albedo", albedo)
  surfaceBody.addOverride("roughness", roughness)
  surfaceBody.addOverride("metallic", metallic)
  surfaceBody.addOverride("worldNormal", worldNormal)

  result = genAst(
    res, hookDefs, deformBody, surfaceBody, 
    deformCombined, surfaceCombined,
    value = ident"value", result = ident"result"
  ):
    block:
      hookDefs

      proc deformCombined(value: Vert): Vert =
        result = value
        deformBody

      proc surfaceCombined(value: Frag): Frag =
        result = value
        surfaceBody

      res.renderer(
        deform = deformCombined, 
        surface = surfaceCombined
      )
