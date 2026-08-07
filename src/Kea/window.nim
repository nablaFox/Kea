import input, target, nimgl/[glfw, opengl]

type
  WindowObj = object
    handle: GLFWWindow

    width*: int32
    height*: int32
   
    mouse*: Mouse
    keyboard*: Keyboard

    backbuffer*: RenderTarget[BackBuffer]

    cursorMode*: CursorMode

  Window* = ref WindowObj

proc `=destroy`(window: var WindowObj) =
  {.cast(raises: []).}:
    window.backbuffer = nil

    if window.handle != nil:
      window.handle.destroyWindow()
      window.handle = nil

proc setCursorMode*(window: Window, mode: CursorMode) =
  window.cursorMode = mode
  window.handle.setInputMode(GLFWCursorSpecial, mode.glfwCursorMode)

proc new*(
  width: Natural,
  height: Natural,
  title: string,
  resizable = false,
  decorated = false,
  cursor = Normal,
  samples: Natural = 8
): Window =
  when not defined(release):
    discard glfwSetErrorCallback(
      proc(error: int32, description: cstring) {.cdecl.} =
        echo "GLFW error ", error, ": ", description
    )

  doAssert glfwInit(), "Failed to initialize GLFW"

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

  doAssert handle != nil, "Failed to create GLFW window"

  handle.makeContextCurrent()

  doAssert glInit(), "Failed to initialize OpenGL"

  if glfwExtensionSupported("GL_ARB_bindless_texture") != GLFWTrue:
    quit("GL_ARB_bindless_texture is not supported")

  loadGL_ARB_bindless_texture()

  if samples > 0:
    glEnable(GL_MULTISAMPLE)

  var framebufferWidth, framebufferHeight: int32

  handle.getFramebufferSize(
    addr framebufferWidth,
    addr framebufferHeight
  )

  result = Window(
    handle: handle,
    width: width.int32,
    height: height.int32,
    backbuffer: target.new(
      framebufferWidth,
      framebufferHeight
    )
  )

  var cursorX, cursorY: float64
  handle.getCursorPos(addr cursorX, addr cursorY)

  result.mouse.position = [
    cursorX.float32,
    cursorY.float32
  ]

  handle.setWindowUserPointer(cast[pointer](result))

  result.setCursorMode(cursor)

  discard handle.setWindowSizeCallback(
    proc(
      handle: GLFWWindow,
      width, height: int32
    ) {.cdecl.} =
      let window =
        cast[Window](handle.getWindowUserPointer())

      window.width = width
      window.height = height
  )

  discard handle.setFramebufferSizeCallback(
    proc(
      handle: GLFWWindow,
      width, height: int32
    ) {.cdecl.} =
      let window =
        cast[Window](handle.getWindowUserPointer())

      window.backbuffer.resize(width, height)
  )

  discard handle.setScrollCallback(
    proc(
      handle: GLFWWindow,
      xOffset, yOffset: float64
    ) {.cdecl.} =
      let window =
        cast[Window](handle.getWindowUserPointer())

      window.mouse.scroll = [
        xOffset.float32,
        yOffset.float32
      ]
  )

proc shouldClose*(window: Window): bool =
  window.handle.windowShouldClose

proc present*(window: Window) =
  window.handle.swapBuffers()

proc close*(window: Window) =
  window.handle.setWindowShouldClose(true)

proc poll*(window: Window) =
  window.mouse.beginFrame()
  window.keyboard.beginFrame()

  glfwPollEvents()

  window.mouse.update(window.handle)
  window.keyboard.update(window.handle)

proc aspect*(window: Window): float32 =
  window.backbuffer.aspect
