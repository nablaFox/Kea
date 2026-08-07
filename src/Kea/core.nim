import 
  renderer,
  camera,
  mesh,
  orbit,
  input,
  pbr,
  window,
  target,
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
    window*: Window

    camera*: Camera
    orbit*: OrbitController

    storage: MeshStorage

    pbr*: PBRRenderer

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
    orbit = orbit.new(target = WorldOrigin),
    vertexCapacity: Natural = DefaultVertexCapacity,
    indexCapacity: Natural = DefaultIndexCapacity,
    resizable = false,
): Kea =
  let window = window.new(
    width,
    height,
    title,
    resizable
  )

  let storage = initMeshStorage(vertexCapacity, indexCapacity)

  result = Kea(
    window: window,
    storage: storage,
    camera: camera.new(Perspective),
    orbit: orbit,
    pbr: pbr.new(storage)
  ) 

proc newMesh*(
    kea: Kea,
    vertices: openArray[Vertex],
    indices: openArray[Index],
): Mesh =
  mesh.new(kea.storage, vertices, indices)

proc newRenderer*[M, G](
  kea: Kea,
  vert: string,
  frag: string,
): Renderer[M, G] =
  renderer.new(kea.storage, vert = vert, frag = frag)

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

    kea.orbit.update(
      camera = kea.camera,
      delta = delta,
      mouse = mouse,
      keyboard = keyboard
    )

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
