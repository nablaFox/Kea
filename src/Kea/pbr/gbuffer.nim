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

proc liftLambda(
  hook: NimNode,
  name: string,
  definitions: NimNode
): NimNode =
  if hook.kind != nnkLambda:
    return hook

  result = genSym(nskProc, name)

  let definition = newNimNode(nnkProcDef, hook)

  for child in hook:
    definition.add child.copyNimTree

  definition[0] = result
  definitions.add definition

proc formalParams(hook: NimNode): NimNode =
  if hook.kind == nnkLambda:
    hook.params
  else:
    hook.getTypeImpl[0]

proc hookArgs(params: openArray[NimNode]): NimNode =
  result = newNimNode(nnkArgList)

  for param in params:
    for i in 0 ..< param.len - 2:
      result.add param[i].copyNimTree

macro renderer*(
  res: Resources,
  deform: typed,
  surface: typed
): untyped =
  let
    hookDefs = newStmtList()

    deformHook = liftLambda(
      deform, "keaDeformHook", hookDefs
    )

    surfaceHook = liftLambda(
      surface, "keaSurfaceHook", hookDefs
    )

    deformParams = deform.formalParams[2..^1]
    surfaceParams = surface.formalParams[2..^1]

  let vertDef = genAst(
    deformHook,
    args = hookArgs(deformParams),
    vert = ident"vert",
    model = ident"model",
    nmat = ident"nmat",
    view = ident"view",
    proj = ident"proj",
    deformed = ident"deformed",
    P = ident"P",
    result = ident"result"
  ):
    proc vert(
      vert: Vertex,
      model: Mat4,
      nmat: Mat3,
      view, proj: Mat4
    ): tuple[
      pos: Vec4,
      uv: Vec2,
      worldNormal: Vec3,
      worldPosition: Vec3
    ] =
      let
        deformed = deformHook(
          Vert(
            position: vert.position,
            normal: vert.normal,
            uv: vert.uv
          ),
          args
        )

        P = model * deformed.position.hom

      result.pos = proj * view * P
      result.worldPosition = P.xyz
      result.worldNormal = nmat * deformed.normal
      result.uv = deformed.uv

  for param in deformParams:
    vertDef.params.add param.copyNimTree

  let fragDef = genAst(
    surfaceHook,
    args = hookArgs(surfaceParams),
    frag = ident"frag",
    worldNormal = ident"worldNormal",
    worldPosition = ident"worldPosition",
    uv = ident"uv",
    albedo = ident"albedo",
    roughness = ident"roughness",
    metallic = ident"metallic",
    eye = ident"eye",
    light = ident"light",
    ltcInverseMatrixLut = ident"ltcInverseMatrixLut",
    ltcMagnitudeFresnelLut = ident"ltcMagnitudeFresnelLut",
    P = ident"P",
    V = ident"V",
    N = ident"N",
    surf = ident"surf",
    surfaceNormal = ident"surfaceNormal",
    lutSize = ident"lutSize",
    x = ident"x",
    y = ident"y",
    lutUv = ident"lutUv",
    shape = ident"shape",
    terms = ident"terms",
    result = ident"result"
  ):
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

        surf = surfaceHook(
          Frag(
            worldNormal: N,
            worldPosition: P,
            albedo: albedo,
            roughness: roughness,
            metallic: metallic,
            view: V,
            uv: uv
          ),
          args
        )

        surfaceNormal = surf.worldNormal.normalize

      result.position = P
      result.albedoMetallic =
        surf.albedo.hom(surf.metallic)

      result.normalRoughness =
        surfaceNormal.hom(surf.roughness)

      result.analytic = block:
        let
          lutSize = ltcInverseMatrixLut.size
          x = surf.roughness
          y = 1 - clamp(
            dot(surfaceNormal, V), 0, 1
          ).sqrt

          lutUv =
            ([x, y] * (lutSize - 1.0'f) + 0.5'f) /
            lutSize

          shape =
            ltcInverseMatrixLut.sample(lutUv)

          terms =
            ltcMagnitudeFresnelLut.sample(lutUv).xy

        light.radiance(
          P, surfaceNormal, V,
          surf.albedo,
          surf.metallic,
          ltcShape = shape,
          ltcAmplitude = terms.x,
          ltcFresnelWeight = terms.y
        )

  for param in surfaceParams:
    fragDef.params.add param.copyNimTree

  result = genAst(
    res,
    hookDefs,
    vertDef,
    fragDef,
    vert = ident"vert",
    frag = ident"frag"
  ):
    block:
      hookDefs
      vertDef
      fragDef

      const key = "pbr/gbuffer:" & $hash(
        vertGlsl(vert) & "\0" &
        fragGlsl(vert, frag)
      )

      res.renderer(
        key = key,
        vert = vert,
        frag = frag,
        globals = GBufferGlobals
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
    deformCombined = genSym(nskProc, "keaDeformCombined")
    surfaceCombined = genSym(nskProc, "keaSurfaceCombined")

  let deformDef = genAst(
    deformCombined,
    value = ident"value",
    result = ident"result"
  ):
    proc deformCombined(value: Vert): Vert =
      result = value

  let surfaceDef = genAst(
    surfaceCombined,
    value = ident"value",
    result = ident"result"
  ):
    proc surfaceCombined(value: Frag): Frag =
      result = value

  proc addOverride(
    definition: NimNode,
    field: string,
    hook: NimNode
  ) =
    if hook.kind == nnkNilLit:
      return

    let
      callable = liftLambda(
        hook, "keaHook_" & field, hookDefs
      )
      params = hook.formalParams[2..^1]
      call = newCall(callable, ident"value")

    for arg in hookArgs(params):
      call.add arg

    for param in params:
      for i in 0 ..< param.len - 2:
        var shared = false

        for existing in definition.params[1..^1]:
          if existing[0].eqIdent(param[i]):
            if not sameType(existing[^2], param[^2]):
              error "conflicting hook parameter types for '" &
                param[i].strVal & "'", param[i]
            shared = true
            break

        if not shared:
          definition.params.add newIdentDefs(
            param[i].copyNimTree,
            param[^2].copyNimTree,
            param[^1].copyNimTree
          )

    definition.body.add newAssignment(
      newDotExpr(ident"result", ident(field)),
      call
    )

  deformDef.addOverride("position", position)
  deformDef.addOverride("normal", normal)

  surfaceDef.addOverride("albedo", albedo)
  surfaceDef.addOverride("roughness", roughness)
  surfaceDef.addOverride("metallic", metallic)
  surfaceDef.addOverride("worldNormal", worldNormal)

  result = genAst(
    res,
    hookDefs,
    deformDef,
    surfaceDef,
    deformCombined,
    surfaceCombined
  ):
    block:
      hookDefs
      deformDef
      surfaceDef

      res.renderer(
        deform = deformCombined,
        surface = surfaceCombined
      )

proc renderer*(res: Resources): GBufferRenderer[PBRMaterial] =
  res.renderer(
    deform = proc(vert: Vert): Vert =
      vert,

    surface = proc(frag: Frag): Frag =
      frag
  )
