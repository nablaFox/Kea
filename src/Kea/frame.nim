import core, target, input, nimgl/glfw

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

iterator frames*(kea: Kea): Frame =
  let
    backbuffer = kea.backbuffer
    startTime = glfwGetTime()

  var previousTime = startTime

  while not kea.shouldClose:
    let currentTime = glfwGetTime()

    let 
      delta = (currentTime - previousTime).float32
      time = (currentTime - startTime).float32
      fps = if delta > 0.0: 1.0 / delta else: 0.0

    kea.poll()

    let 
      keyboard = kea.keyboard
      mouse = kea.mouse

    previousTime = currentTime

    yield Frame(
      delta: delta,
      fps: fps,
      time: time,
      keyboard: keyboard,
      mouse: mouse,
      aspect: kea.aspect,
      backbuffer: backbuffer,
      width: kea.width,
      height: kea.height,
      present: proc() = kea.present()
    )
