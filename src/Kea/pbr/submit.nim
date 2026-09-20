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
  gbuffer,
  pbr

proc draw*[M](
  items: openArray[RenderItem[M]],
  renderer: GBufferRenderer[M]
): PBRDraw =
  let ownedItems = @items

  result = proc(
    gbuffer: GBufferTarget,
    globals: GBufferGlobals,
    parentModel: Mat4
  ) =
    renderer.render(
      target = gbuffer,
      items = ownedItems,
      globals = globals,
      parentModel = parentModel
    )

proc draw*[M](
  mesh: Mesh,
  transform: Transform,
  renderer: GBufferRenderer[M],
  material: M,
  topology: Topology = Triangles,
): PBRDraw =
  draw(
    items = @[
      item.new(
        mesh,
        transform,
        material,
        topology
      )
    ],
    renderer = renderer
  )

proc draw*[M](
  mesh: Mesh,
  renderer: GBufferRenderer[M],
  material: M,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0),
  topology: Topology = Triangles,
): PBRDraw =
  draw(
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
    renderer = renderer,
    topology = topology
  )

proc draw*(
  res: Resources,
  renderable: Renderable,
  material: PBRMaterial = PBRMaterial.default,
  renderer: GBufferRenderer[PBRMaterial] = nil
): PBRDraw =
  draw[PBRMaterial](
    mesh = renderable.mesh,
    transform = renderable.transform,
    topology = renderable.topology,
    material = material,
    renderer =
      if renderer == nil: res.renderer
      else: renderer
  )

proc draw*(
  res: Resources,
  mesh: Mesh,
  transform: Transform,
  material: PBRMaterial = PBRMaterial.default,
  topology: Topology = Triangles,
  renderer: GBufferRenderer[PBRMaterial] = nil
): PBRDraw =
  draw[PBRMaterial](
    mesh,
    transform,
    topology = topology,
    material = material,
    renderer =
      if renderer == nil: res.renderer
      else: renderer
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
  renderer: GBufferRenderer[PBRMaterial] = nil
): PBRDraw =
  draw[PBRMaterial](
    mesh,
    x = x,
    y = y,
    z = z,
    yaw = yaw,
    pitch = pitch,
    roll = roll,
    scale = scale,
    topology = topology,
    material = material,
    renderer =
      if renderer == nil: res.renderer
      else: renderer
  )

proc submit*(pbr: PBR, draws: openArray[PBRDraw]) =
  pbr.pending.add draws

proc submit*(pbr: PBR, draw: PBRDraw) =
  pbr.pending.add draw

proc submit*(pbr: PBR, source: PBRSource) =
  pbr.pending.add source.draws(pbr.res)

proc submit*(
  pbr: PBR,
  source: PBRSource,
  transform: Transform
) =
  let
    draws = source.draws(pbr.res)
    model = transform.model

  let grouped: PBRDraw = proc(
    gbuffer: GBufferTarget,
    globals: GBufferGlobals,
    parentModel: Mat4
  ) =
    for draw in draws:
      draw(gbuffer, globals, parentModel * model)

  pbr.pending.add grouped

proc submit*[M](
  pbr: PBR,
  items: openArray[RenderItem[M]],
  renderer: GBufferRenderer[M]
) =
  pbr.submit draw(
    items = items,
    renderer = renderer
  )

proc submit*[M](
  pbr: PBR,
  item: RenderItem[M],
  renderer: GBufferRenderer[M]
) =
  pbr.submit(
    items = @[item],
    renderer = renderer
  )

proc submit*[M](
  pbr: PBR,
  mesh: Mesh,
  transform: Transform,
  material: M,
  renderer: GBufferRenderer[M],
  topology: Topology = Triangles,
) =
  pbr.submit(
    item = item.new(
      mesh,
      transform,
      material,
      topology
    ),
    renderer = renderer
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
  renderer: GBufferRenderer[M],
  topology: Topology = Triangles,
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
    renderer = renderer
  )

proc submit*(
  pbr: PBR,
  renderable: Renderable,
  material: PBRMaterial = PBRMaterial.default,
  renderer: GBufferRenderer[PBRMaterial] = nil
) =
  submit[PBRMaterial](
    pbr,
    mesh = renderable.mesh,
    transform = renderable.transform,
    topology = renderable.topology,
    material = material,
    renderer =
      if renderer == nil: pbr.res.renderer
      else: renderer
  )

proc submit*(
  pbr: PBR,
  mesh: Mesh,
  transform: Transform,
  material: PBRMaterial = PBRMaterial.default,
  topology: Topology = Triangles,
  renderer: GBufferRenderer[PBRMaterial] = nil
) =
  submit[PBRMaterial](
    pbr,
    mesh,
    transform,
    material = material,
    topology = topology,
    renderer =
      if renderer == nil: pbr.res.renderer
      else: renderer
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
  renderer: GBufferRenderer[PBRMaterial] = nil
) =
  submit[PBRMaterial](
    pbr,
    mesh,
    x, y, z,
    yaw, pitch, roll,
    scale,
    material = material,
    topology = topology,
    renderer =
      if renderer == nil: pbr.res.renderer
      else: renderer
  )

proc submit*(
  pbr: PBR,
  item: RenderItem[PBRMaterial],
  renderer: GBufferRenderer[PBRMaterial] = nil
) =
  submit[PBRMaterial](
    pbr,
    item,
    renderer =
      if renderer == nil: pbr.res.renderer
      else: renderer
  )
