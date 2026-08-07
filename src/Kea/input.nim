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
    LeftShift
    A
    B
    C
    D
    E
    F
    G
    H
    I
    J
    K
    L
    M
    N
    O
    P
    Q
    R
    S
    T
    U
    V
    W
    X
    Y
    Z
    Zero
    One
    Two
    Three
    Four
    Five
    Six
    Seven
    Eight
    Nine

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

  CursorMode* = enum
    Normal
    Hidden
    Disabled

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
  of LeftShift: int32(GLFWKey.LeftShift)
  of A: int32(GLFWKey.A)
  of B: int32(GLFWKey.B)
  of C: int32(GLFWKey.C)
  of D: int32(GLFWKey.D)
  of E: int32(GLFWKey.E)
  of F: int32(GLFWKey.F)
  of G: int32(GLFWKey.G)
  of H: int32(GLFWKey.H)
  of I: int32(GLFWKey.I)
  of J: int32(GLFWKey.J)
  of K: int32(GLFWKey.K)
  of L: int32(GLFWKey.L)
  of M: int32(GLFWKey.M)
  of N: int32(GLFWKey.N)
  of O: int32(GLFWKey.O)
  of P: int32(GLFWKey.P)
  of Q: int32(GLFWKey.Q)
  of R: int32(GLFWKey.R)
  of S: int32(GLFWKey.S)
  of T: int32(GLFWKey.T)
  of U: int32(GLFWKey.U)
  of V: int32(GLFWKey.V)
  of W: int32(GLFWKey.W)
  of X: int32(GLFWKey.X)
  of Y: int32(GLFWKey.Y)
  of Z: int32(GLFWKey.Z) 
  of Zero: int32(GLFWKey.K0)
  of One: int32(GLFWKey.K1)
  of Two: int32(GLFWKey.K2)
  of Three: int32(GLFWKey.K3)
  of Four: int32(GLFWKey.K4)
  of Five: int32(GLFWKey.K5)
  of Six: int32(GLFWKey.K6)
  of Seven: int32(GLFWKey.K7)
  of Eight: int32(GLFWKey.K8)
  of Nine: int32(GLFWKey.K9)

proc glfwCursorMode*(mode: CursorMode): int32 =
  case mode
  of Normal: GLFWCursorNormal
  of Hidden: GLFWCursorHidden
  of Disabled: GLFWCursorDisabled

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
