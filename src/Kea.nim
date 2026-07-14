import nimgl/[glfw, opengl]

import Kea/[
  core,
  math,
  keys,
  input,
  transform,
  material,
  mesh,
  drawable,
  frame
]

export
  core,
  keys,
  math,
  input,
  transform,
  material,
  mesh,
  drawable,
  frame

const vertices: array[9, float32] =
  [0.0'f32, 0.5'f32, 0.0'f32, -0.5'f32, -0.5'f32, 0.0'f32, 0.5'f32, -0.5'f32, 0.0'f32]

const
  vertexShaderSource = """
     #version 330 core

     layout (location = 0) in vec3 position;

     void main() {
        gl_Position = vec4(position, 1.0);
     }
  """

  fragmentShaderSource = """
     #version 330 core

     out vec4 FragColor;

     void main() {
        FragColor = vec4(1.0, 0.5, 0.2, 1.0);
     }
  """

proc compileShader(kind: GLenum, source: string): GLuint =
  result = glCreateShader(kind)

  let cSource = source.cstring

  glShaderSource(result, 1, addr cSource, nil)
  glCompileShader(result)

  var success: GLint
  glGetShaderiv(result, GL_COMPILE_STATUS, addr success)

  if success == 0:
    var log = newString(512)
    glGetShaderInfoLog(result, 512, nil, log.cstring)
    quit("Shader compilation failed:\n" & log)

proc createShaderProgram*(vert: string, frag: string): GLuint =
  let vertexShader = compileShader(GL_VERTEX_SHADER, vert)
  let fragmentShader = compileShader(GL_FRAGMENT_SHADER, frag)

  result = glCreateProgram()

  glAttachShader(result, vertexShader)
  glAttachShader(result, fragmentShader)
  glLinkProgram(result)
  
  var success: GLint
  glGetProgramiv(result, GL_LINK_STATUS, addr success)
 
  if success == 0:
    var log = newString(512)
    glGetProgramInfoLog(result, 512, nil, log.cstring)
    quit("Shader linking failed:\n" & log)

  glDeleteShader(vertexShader)
  glDeleteShader(fragmentShader)

proc main() =
  doAssert glfwInit(), "Failed to initialize GLFW"
  defer: glfwTerminate()

  glfwWindowHint(GLFWResizable, GLFW_FALSE)
  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWSamples, 8)

  let window = glfwCreateWindow(800, 600, "Kea")

  doAssert window != nil, "Failed to create GLFW window"
  defer: window.destroyWindow()

  window.makeContextCurrent()

  doAssert glInit(), "Failed to initialize OpenGL"

  glEnable(GL_MULTISAMPLE)

  var vao, vbo: GLuint

  glGenVertexArrays(1, addr vao)
  glGenBuffers(1, addr vbo)

  defer: 
    glDeleteBuffers(1, addr vbo)
    glDeleteVertexArrays(1, addr vao)

  glBindVertexArray(vao)
  glBindBuffer(GL_ARRAY_BUFFER, vbo)

  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), addr vertices[0], GL_STATIC_DRAW)

  glVertexAttribPointer(
    0'u32,
    3,
    EGL_FLOAT,
    false,
    3 * sizeof(GLfloat),
    nil
  )

  glEnableVertexAttribArray(0)

  glBindBuffer(GL_ARRAY_BUFFER, 0)
  glBindVertexArray(0)

  let shaderProgram = createShaderProgram(vertexShaderSource, fragmentShaderSource)

  defer: glDeleteProgram(shaderProgram)

  while not window.windowShouldClose:
    glClearColor(0.1, 0.1, 0.1, 1.0)

    glClear(GL_COLOR_BUFFER_BIT)

    glUseProgram(shaderProgram)

    glBindVertexArray(vao)

    glDrawArrays(GL_TRIANGLES, 0, vertices.len)

    window.swapBuffers()

    glfwPollEvents()

when isMainModule:
  let kea = initKea(width=800, height=600, title="demo")

  let ball = kea.createMesh(Sphere)

  let cube = kea.createMesh(@[], @[])

  let drawableBall = kea.add(ball)

  let drawablePyramid = kea.add(Pyramid)

  for frame in kea.frames:
    if frame.input.keyPressed(Escape):
      break

    echo frame.delta

    kea.render()

  main()
