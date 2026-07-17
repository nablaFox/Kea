import nimgl/[opengl], mesh

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

proc createVAO*(meshStorage: MeshStorage): GLuint =
  glGenVertexArrays(1, addr result)
  glBindVertexArray(result)

  glBindBuffer(GL_ARRAY_BUFFER, meshStorage.vertexBuffer)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, meshStorage.indexBuffer)

  glVertexAttribPointer(
    0'u32, 
    3, 
    EGL_FLOAT, 
    false, 
    GLsizei(sizeof(Vertex)), nil
  )
  glEnableVertexAttribArray(0)

  glVertexAttribPointer(
    1'u32, 
    3, 
    EGL_FLOAT, 
    false, 
    GLsizei(sizeof(Vertex)), 
    cast[pointer](offsetof(Vertex, normal))
  )
  glEnableVertexAttribArray(1)

  glVertexAttribPointer(
    2'u32, 
    2, 
    EGL_FLOAT, 
    false, 
    GLsizei(sizeof(Vertex)), 
    cast[pointer](offsetof(Vertex, uv))
  )
  glEnableVertexAttribArray(2)
