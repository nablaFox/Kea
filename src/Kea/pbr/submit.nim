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
  hooks: GBufferRenderer[M] = nil
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
  material: M,
  topology: Topology = Triangles,
  hooks: GBufferRenderer[M] = nil
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
  material: M,
  topology: Topology = Triangles,
  hooks: GBufferRenderer[M] = nil
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
      scale = scale
    ),
    material = material,
    topology = topology,
    hooks = hooks
  )

proc draw*(
  res: Resources,
  renderable: Renderable,
  material: PBRMaterial = PBRMaterial.default,
  topology: Topology = Triangles,
  hooks: GBufferRenderer[PBRMaterial] = nil
): PBRDraw =
  draw[PBRMaterial](
    res,
    renderable.mesh,
    renderable.transform,
    material = material,
    topology = topology,
    hooks = hooks
  )

proc draw*(
  res: Resources,
  mesh: Mesh,
  transform: Transform,
  material: PBRMaterial = PBRMaterial.default,
  topology: Topology = Triangles,
  hooks: GBufferRenderer[PBRMaterial] = nil
): PBRDraw =
  draw[PBRMaterial](
    res,
    mesh,
    transform,
    material = material,
    topology = topology,
    hooks = hooks
  )

proc draw*(
  res: Resources,
  mesh: Mesh,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0),
  material: PBRMaterial = PBRMaterial.default,
  topology: Topology = Triangles,
  hooks: GBufferRenderer[PBRMaterial] = nil
): PBRDraw =
  draw[PBRMaterial](
    res,
    mesh,
    x, y, z,
    yaw, pitch, roll,
    scale,
    material = material,
    topology = topology,
    hooks = hooks
  )


proc submit*(pbr: PBR, draws: openArray[PBRDraw]) =
  pbr.pending.add draws

proc submit*(pbr: PBR, draw: PBRDraw) =
  pbr.pending.add draw

proc submit*(pbr: PBR, source: PBRSource) =
  pbr.pending.add source.draws(pbr.res)

proc submit*[M](
  pbr: PBR,
  items: openArray[RenderItem[M]],
  hooks: GBufferRenderer[M] = nil
) =
  pbr.submit draw(
    pbr.res,
    items = items,
    hooks = hooks
  )

proc submit*[M](
  pbr: PBR,
  item: RenderItem[M],
  hooks: GBufferRenderer[M] = nil
) =
  pbr.submit(
    items = @[item],
    hooks = hooks
  )

proc submit*[M](
  pbr: PBR,
  mesh: Mesh,
  transform: Transform,
  material: M,
  topology: Topology = Triangles,
  hooks: GBufferRenderer[M] = nil
) =
  pbr.submit(
    item = item.new(
      mesh,
      transform,
      material,
      topology
    ),
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
  topology: Topology = Triangles,
  hooks: GBufferRenderer[M] = nil
) =
  pbr.submit(
    mesh,
    transform.new(
      x = x,
      y = y,
      z = z,
      yaw = yaw,
      pitch = pitch,
      roll = roll,
      scale = scale
    ),
    material = material,
    topology = topology,
    hooks = hooks
  )

proc submit*(
  pbr: PBR,
  renderable: Renderable,
  material: PBRMaterial = PBRMaterial.default,
  topology: Topology = Triangles,
  hooks: GBufferRenderer[PBRMaterial] = nil
) =
  submit[PBRMaterial](
    pbr,
    renderable.mesh,
    renderable.transform,
    material = material,
    topology = topology,
    hooks = hooks
  )

proc submit*(
  pbr: PBR,
  mesh: Mesh,
  transform: Transform,
  material: PBRMaterial = PBRMaterial.default,
  topology: Topology = Triangles,
  hooks: GBufferRenderer[PBRMaterial] = nil
) =
  submit[PBRMaterial](
    pbr,
    mesh,
    transform,
    material = material,
    topology = topology,
    hooks = hooks
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
  material: PBRMaterial = PBRMaterial.default,
  topology: Topology = Triangles,
  hooks: GBufferRenderer[PBRMaterial] = nil
) =
  submit[PBRMaterial](
    pbr,
    mesh,
    x, y, z,
    yaw, pitch, roll,
    scale,
    material = material,
    topology = topology,
    hooks = hooks
  )

proc submit*(
  pbr: PBR,
  item: RenderItem[PBRMaterial],
  hooks: GBufferRenderer[PBRMaterial] = nil
) =
  submit[PBRMaterial](
    pbr,
    item,
    hooks = hooks
  )
