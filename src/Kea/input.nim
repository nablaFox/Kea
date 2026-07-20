import math, nimgl/glfw

type
  Key* = enum
    Space
    Escape
    Tab
    Up
    Down
    Left
    Right

  MouseButton* = enum
    Left
    Middle
    Right
    Back
    Forward

  Mouse* = object
    current: array[MouseButton, bool]
    previous: array[MouseButton, bool]

    position*: Vec2
    delta*: Vec2
    scroll*: Vec2

  Keyboard* = object
    current: array[Key, bool]
    previous: array[Key, bool]

proc glfwButton(button: MouseButton): GLFWMouseButton =
  case button
  of MouseButton.Left:
    GLFWMouseButton.Button1
  of MouseButton.Right:
    GLFWMouseButton.Button2
  of MouseButton.Middle:
    GLFWMouseButton.Button3
  of MouseButton.Back:
    GLFWMouseButton.Button4
  of MouseButton.Forward:
    GLFWMouseButton.Button5

proc glfwKey*(key: Key): int32 =
  case key
  of Space: int32(GLFWKey.Space)
  of Escape: int32(GLFWKey.Escape)
  of Tab: int32(GLFWKey.Tab)
  of Up: int32(GLFWKey.Up)
  of Down: int32(GLFWKey.Down)
  of Left: int32(GLFWKey.Left)
  of Right: int32(GLFWKey.Right)

proc beginFrame*(keyboard: var Keyboard) =
  keyboard.previous = keyboard.current

proc update*(keyboard: var Keyboard, window: GLFWWindow) =
  for key in Key:
    keyboard.current[key] =
      window.getKey(key.glfwKey) == GLFWPress

proc down*(keyboard: Keyboard, key: Key): bool =
  keyboard.current[key]

proc pressed*(keyboard: Keyboard, key: Key): bool =
  keyboard.current[key] and not keyboard.previous[key]

proc released*(keyboard: Keyboard, key: Key): bool =
  not keyboard.current[key] and keyboard.previous[key]

proc beginFrame*(mouse: var Mouse) =
  mouse.previous = mouse.current
  mouse.delta = vec2(0.0)
  mouse.scroll = vec2(0.0)

proc update*(mouse: var Mouse, window: GLFWWindow) =
  for button in MouseButton:
    mouse.current[button] =
      window.getMouseButton(button.glfwButton) == GLFWPress

  var x, y: float64
  window.getCursorPos(addr x, addr y)

  let position: Vec2 = [x.float32, y.float32]

  mouse.delta = [
    position.x - mouse.position.x,
    position.y - mouse.position.y,
  ]

  mouse.position = position

proc down*(mouse: Mouse, button: MouseButton): bool =
  mouse.current[button]

proc pressed*(mouse: Mouse, button: MouseButton): bool =
  mouse.current[button] and not mouse.previous[button]

proc released*(mouse: Mouse, button: MouseButton): bool =
  not mouse.current[button] and mouse.previous[button]

