import nimgl/opengl, math

proc compile(kind: GLenum, source: string): GLuint =
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

proc createProgram*(vert: string, frag: string): GLuint =
  let vertexShader = compile(GL_VERTEX_SHADER, vert)
  let fragmentShader = compile(GL_FRAGMENT_SHADER, frag)

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

proc setUniform*(location: GLint, value: float32) =
  glUniform1f(location, value)

proc setUniform*(location: GLint, value: Vec3) =
  glUniform3fv(location, 1, addr value[0])

proc setUniform*(location: GLint, value: Vec4) =
  glUniform4fv(location, 1, addr value[0])

proc setUniform*(location: GLint, value: Mat4) =
  glUniformMatrix4fv(
    location,
    1,
    true,
    addr value[0][0]
  )

proc setUniform*(location: GLint, value: Mat3) = 
  glUniformMatrix3fv(
    location,
    1,
    true,
    addr value[0][0]
  ) 
