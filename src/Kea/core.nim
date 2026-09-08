import input, nimgl/[glfw, opengl]

export opengl

type
  KeaObj = object
    handle: GLFWWindow

    width: int32
    height: int32

    mouse: Mouse
    keyboard: Keyboard

    cursorMode: CursorMode

  Kea* = ref KeaObj

proc `=destroy`(kea: var KeaObj) =
  {.cast(raises: []).}:
    if kea.handle != nil:
      kea.handle.destroyWindow()
      kea.handle = nil

    glfwTerminate()

proc `cursor=`*(kea: Kea, cursor: CursorMode) =
  kea.cursorMode = cursor
  kea.handle.setInputMode(GLFWCursorSpecial, cursor.glfwCursorMode)

proc cursor*(kea: Kea): CursorMode =
  kea.cursorMode

proc rebaseMouse(kea: Kea) =
  var x, y: float64
  kea.handle.getCursorPos(addr x, addr y)

  kea.mouse.position = [x.float32, y.float32]
  kea.mouse.delta = [0.0'f, 0.0]

proc init*(
  width: Natural,
  height: Natural,
  title: string,
  resizable = false,
  decorated = false,
  cursor = Normal,
  samples: Natural = 8
): Kea =
  when not defined(release):
    discard glfwSetErrorCallback(
      proc(error: int32, description: cstring) {.cdecl.} =
        echo "GLFW error ", error, ": ", description
    )

  doAssert glfwInit(), "Failed to initialize GLFW"

  result = Kea(
    width: width.int32,
    height: height.int32,
  )

  glfwWindowHint(GLFWContextVersionMajor, 4)
  glfwWindowHint(GLFWContextVersionMinor, 0)
  glfwWindowHint(GLFWOpenglProfile, GLFWOpenglCoreProfile)
  glfwWindowHint(GLFWSamples, samples.int32)

  glfwWindowHint(
    GLFWDecorated,
    if decorated: GLFWTrue else: GLFWFalse
  )

  if not resizable:
    glfwWindowHint(GLFWResizable, GLFWFalse)

  let handle = glfwCreateWindow(
    width.int32,
    height.int32,
    title
  )

  result.handle = handle

  doAssert handle != nil, "Failed to create GLFW window"

  handle.makeContextCurrent()

  doAssert glInit(), "Failed to initialize OpenGL"

  if glfwExtensionSupported("GL_ARB_bindless_texture") != GLFWTrue:
    quit("GL_ARB_bindless_texture is not supported")

  loadGL_ARB_bindless_texture()

  if samples > 0:
    glEnable(GL_MULTISAMPLE)

  result.rebaseMouse()

  handle.setWindowUserPointer(cast[pointer](result))

  result.cursor = cursor

  discard handle.setWindowSizeCallback(
    proc(
      handle: GLFWWindow,
      width, height: int32
    ) {.cdecl.} =
      let kea =
        cast[Kea](handle.getWindowUserPointer())

      kea.width = width
      kea.height = height
      kea.rebaseMouse()
  )

  discard handle.setScrollCallback(
    proc(
      handle: GLFWWindow,
      xOffset, yOffset: float64
    ) {.cdecl.} =
      let kea =
        cast[Kea](handle.getWindowUserPointer())

      kea.mouse.scroll = [
        xOffset.float32,
        yOffset.float32
      ]
  )

  discard handle.setWindowPosCallback(
    proc(
      handle: GLFWWindow,
      x, y: int32
    ) {.cdecl.} =
      let kea =
        cast[Kea](handle.getWindowUserPointer())

      kea.rebaseMouse()
  )

proc shouldClose*(kea: Kea): bool =
  kea.handle.windowShouldClose

proc present*(kea: Kea) =
  kea.handle.swapBuffers()

proc close*(kea: Kea) =
  kea.handle.setWindowShouldClose(true)

proc poll*(kea: Kea) =
  kea.mouse.beginFrame()
  kea.keyboard.beginFrame()

  glfwPollEvents()

  kea.mouse.update(kea.handle)
  kea.keyboard.update(kea.handle)

proc width*(kea: Kea): int32 =
  kea.width

proc height*(kea: Kea): int32 =
  kea.height

proc mouse*(kea: Kea): Mouse =
  kea.mouse

proc keyboard*(kea: Kea): Keyboard =
  kea.keyboard

proc framebufferSize*(kea: Kea): tuple[width, height: int32] =
  kea.handle.getFramebufferSize(
    addr result.width,
    addr result.height
  )

proc aspect*(kea: Kea): float32 =
  let (width, height) = kea.framebufferSize

  if height == 0:
    return 1.0'f

  width.float32 / height.float32
