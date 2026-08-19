import 
  renderer,
  camera,
  mesh,
  orbit,
  input,
  pbr,
  window,
  target,
  primitives,
  transform,
  nimgl/glfw

const
  DefaultVertexCapacity {.intdefine: "kea.vertexCapacity".} = 1_000_000
  DefaultIndexCapacity {.intdefine: "kea.indexCapacity".} = 1_000_000

type
  Frame* = object
    delta*: float32
    fps*: float32
    time*: float32
    keyboard*: Keyboard
    mouse*: Mouse
    aspect*: float32
    backbuffer*: RenderTarget[BackBuffer]
    width*: int32
    height*: int32
    present*: proc() {.closure.}

  KeaObj = object
    window: Window

    storage: MeshStorage

    pbr: PBRRenderer

  Kea* = ref KeaObj

proc `=destroy`(kea: var KeaObj) =
  {.cast(raises: []).}:
    kea.pbr = nil

    if kea.storage != nil:
      kea.storage.destroy()
      kea.storage = nil

    glfwTerminate()

proc init*(
    width: Natural,
    height: Natural,
    title: string,
    vertexCapacity: Natural = DefaultVertexCapacity,
    indexCapacity: Natural = DefaultIndexCapacity,
    resizable = false,
    decorated = false,
    cursor = Normal,
): Kea =
  let window = window.new(
    width,
    height,
    title,
    resizable,
    decorated,
    cursor
  )

  let storage = initMeshStorage(vertexCapacity, indexCapacity)

  result = Kea(
    window: window,
    storage: storage,
    pbr: pbr.new(storage)
  ) 

proc newMesh*(
    kea: Kea,
    vertices: openArray[Vertex],
    indices: openArray[Index],
): Mesh =
  mesh.new(kea.storage, vertices, indices)

proc newRenderer*[G, M](
  kea: Kea,
  material: typedesc[M],
  vert: string,
  frag: string,
  globals: G = G.default
): Renderer[G, M] =
  renderer.new[G, M](
    kea.storage, 
    vert = vert, 
    frag = frag, 
    globals = globals
  )

proc add*(
  kea: Kea,
  item: RenderItem[PBRMaterial],
): RenderItem[PBRMaterial] =
  kea.pbr.add(item)

proc add*(
  kea: Kea,
  primitive: Primitive,
  material: PBRMaterial,
  transform = Identity,
  topology = Triangles,
): RenderItem[PBRMaterial] =
  kea.pbr.add(
    primitive,
    material,
    transform,
    topology
  )

proc add*(
  kea: Kea,
  primitive: Primitive,
  material: PBRMaterial,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  topology = Triangles,
): RenderItem[PBRMaterial] =
  kea.pbr.add(
    primitive,
    material,
    x = x,
    y = y,
    z = z,
    pitch = pitch,
    yaw = yaw,
    roll = roll,
    scale = scale,
    topology
  )

proc add*(
  kea: Kea,
  mesh: Mesh,
  material: PBRMaterial,
  transform = Identity,
  topology = Triangles,
): RenderItem[PBRMaterial] =
  kea.pbr.add(
    mesh,
    material,
    transform,
    topology
  )

proc add*(
  kea: Kea,
  mesh: Mesh,
  material: PBRMaterial,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: float32 = 1.0,
  topology = Triangles,
): RenderItem[PBRMaterial] =
  kea.pbr.add(
    mesh,
    material,
    x = x,
    y = y,
    z = z,
    pitch = pitch,
    yaw = yaw,
    roll = roll,
    scale = scale,
    topology
  )

proc render*(kea: Kea, target: RenderTarget, camera: Camera) =
  kea.pbr.eye = camera.positioned
  kea.pbr.view = camera.view
  kea.pbr.proj = camera.proj target.aspect

  kea.pbr.render(target)

proc update*(orbit: var OrbitController, frame: Frame) =
  orbit.update(
    delta = frame.delta,
    mouse = frame.mouse, 
    keyboard = frame.keyboard, 
  )

proc `cursor=`*(kea: Kea, cursor: CursorMode) =
  kea.window.setCursorMode(cursor)

proc cursor*(kea: Kea): CursorMode =
  kea.window.cursorMode

proc `light`*(kea: Kea): var RectLight =
  kea.pbr.light

iterator frames*(kea: Kea): Frame =
  let startTime = glfwGetTime()
  var previousTime = startTime

  while not kea.window.shouldClose:
    let currentTime = glfwGetTime()

    let delta = (currentTime - previousTime).float32
    let time = (currentTime - startTime).float32
    let fps = if delta > 0.0: 1.0 / delta else: 0.0
    let keyboard = kea.window.keyboard
    let mouse = kea.window.mouse

    previousTime = currentTime

    kea.window.poll()

    yield Frame(
      delta: delta,
      fps: fps,
      time: time,
      keyboard: keyboard,
      mouse: mouse,
      aspect: kea.window.aspect,
      backbuffer: kea.window.backbuffer,
      width: kea.window.width,
      height: kea.window.height,
      present: proc() = kea.window.present()
    )
