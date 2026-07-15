import keys
import nimgl/glfw

type
  Input* = object
    currentKeys: array[Key, bool]
    previousKeys: array[Key, bool]

proc update*(input: var Input, window: GLFWWindow) =
  input.previousKeys = input.currentKeys

  for key in Key:
    input.currentKeys[key] =
      window.getKey(key.glfwKey) == GLFW_PRESS

proc down*(input: Input, key: Key): bool =
  input.currentKeys[key]

proc pressed*(input: Input, key: Key): bool =
  input.currentKeys[key] and not input.previousKeys[key]

proc released*(input: Input, key: Key): bool =
  not input.currentKeys[key] and input.previousKeys[key]
