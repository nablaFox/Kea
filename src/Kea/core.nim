import 
  renderer,
  camera,
  mesh,
  orbit,
  input,
  math,
  window,
  target,
  primitives,
  transform,
  shader,
  texture,
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
    backbuffer*: BackBufferTarget
    width*: int32
    height*: int32
    present*: proc() {.closure.}

  KeaObj = object
    window: Window
    storage: MeshStorage

  Kea* = ref KeaObj

proc `=destroy`(kea: var KeaObj) =
  {.cast(raises: []).}:
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
    storage: storage
  ) 

proc mesh*(
  kea: Kea,
  vertices: openArray[Vertex],
  indices: openArray[Index],
): Mesh =
  mesh.new(kea.storage, vertices, indices)

template renderer*[G: tuple](
  kea: Kea,
  vert, frag: typed,
  globals: G = (),
): untyped =
  renderer.new(
    kea.storage,
    vert,
    frag,
    globals
  )

proc renderable*(
  kea: Kea,
  primitive: Primitive,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0)
): Renderable = discard

template render*[T: tuple](
  kea: Kea,
  renderable: Renderable,
  vert, frag: typed,
  params: T = (),
  topology = Triangles  
) = discard

proc `cursor=`*(kea: Kea, cursor: CursorMode) =
  kea.window.setCursorMode(cursor)

proc cursor*(kea: Kea): CursorMode =
  kea.window.cursorMode

proc update*(orbit: var OrbitController, frame: Frame) =
  orbit.update(
    delta = frame.delta,
    mouse = frame.mouse, 
    keyboard = frame.keyboard, 
  )

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
