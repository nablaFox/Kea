import
  Kea/[
    resources,
    renderer,
    item,
    target,
    mesh,
    transform,
    math
  ],
  hooks,
  pbr

proc draw*[M](
  res: Resources,
  items: openArray[RenderItem[M]],
  hooks: GBufferRenderer[M] = nil,
): PBRDraw =
  let ownedItems = @items

  result = proc(
    gbuffer: GBufferTarget,
    globals: GBufferGlobals
  ) =
    let renderer =
      if hooks != nil: hooks
      else: res.hooks

    renderer.render(
      target = gbuffer,
      items = ownedItems,
      globals = globals
    )

proc draw*[M](
  res: Resources,
  mesh: Mesh,
  transform: Transform,
  hooks: GBufferRenderer[M] = nil,
  material: M = M.default,
  topology: Topology = Triangles
): PBRDraw =
  draw(
    res,
    items = @[
      item.new(
        mesh,
        transform,
        material,
        topology
      )
    ],
    hooks = hooks
  )

proc draw*[M](
  res: Resources,
  mesh: Mesh,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0),
  hooks: GBufferRenderer[M] = nil,
  material: M = M.default,
  topology: Topology = Triangles
): PBRDraw =
  draw(
    res,
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
    hooks = hooks,
    material = material,
    topology = topology
  )

proc submit*(pbr: PBR, draws: openArray[PBRDraw]) =
  pbr.pending.add draws

proc submit*(pbr: PBR, draw: PBRDraw) =
  pbr.pending.add draw

proc submit*(pbr: PBR, source: PBRSource) =
  pbr.pending.add source.draws(pbr.res)

proc submit*[M](
  pbr: PBR,
  mesh: Mesh,
  transform: Transform,
  hooks: GBufferRenderer[M] = nil,
  material: M = M.default,
  topology: Topology = Triangles
) =
  pbr.submit draw(
    pbr.res,
    items = @[
      item.new(
        mesh,
        transform,
        material,
        topology
      )
    ],
    hooks = hooks
  )

proc submit*[M](
  pbr: PBR,
  mesh: Mesh,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0),
  material: M,
  hooks: GBufferRenderer[M] = nil,
  topology: Topology = Triangles
) =
  pbr.submit draw(
    pbr.res,
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
    hooks = hooks,
    material = material,
    topology = topology
  )

proc submit*(
  pbr: PBR,
  mesh: Mesh,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0),
  hooks: GBufferRenderer[PBRMaterial] = nil,
  material: PBRMaterial = PBRMaterial.default,
  topology: Topology = Triangles
) =
  submit[PBRMaterial](
    pbr,
    mesh,
    x, y, z,
    yaw, pitch, roll,
    scale,
    material,
    hooks,
    topology
  )
