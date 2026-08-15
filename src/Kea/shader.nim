import nimgl/opengl, math, texture

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

proc setUniform*(location: GLint, value: Natural) =
  glUniform1ui(location, value.GLuint)

proc setUniform*(location: GLint, value: float32) =
  glUniform1f(location, value)

proc setUniform*(location: GLint, value: Vec2) =
  glUniform2fv(location, 1, addr value[0])

proc setUniform*(location: GLint, value: Vec3) =
  glUniform3fv(location, 1, addr value[0])

proc setUniform*(location: GLint, value: Vec4) =
  glUniform4fv(location, 1, addr value[0])

proc setUniform*(location: GLint, value: Mat4) =
  glUniformMatrix4fv(location, 1, true, addr value[0][0])

proc setUniform*(location: GLint, value: Mat3) = 
  glUniformMatrix3fv(location, 1, true, addr value[0][0]) 

proc setUniform*[K: static TextureKind](location: GLint, texture: Texture[K]) =
  if location >= 0:
    glUniformHandleui64ARB(location, texture.residentHandle)

proc setUniforms*[T: tuple](locations: openArray[GLint], values: T) =
  var index = 0

  proc set[T](
    locations: openArray[GLint],
    value: T,
    index: var int
  ) =
    when compiles(setUniform(GLint(0), value)):
      setUniform(locations[index], value)
      inc index

    elif T is tuple or T is object:
      for _, field in value.fieldPairs:
        set(locations, field, index)

    else:
      {.error: "Unsupported uniform type: " & $T.}

  set(locations, values, index)

proc uniformLocation*(program: GLuint, name: string): GLint =
  glGetUniformLocation(program, name)

proc uniformLocations*[T](program: GLuint): seq[GLint] =
  var value: T

  proc collect[T](
    program: GLuint,
    name: string,
    value: T,
    locations: var seq[GLint]
  ) =
    when compiles(setUniform(GLint(0), value)):
      locations.add glGetUniformLocation(program, name)

    elif T is tuple or T is object:
      for fieldName, fieldValue in value.fieldPairs:
        let childName =
          if name.len == 0: fieldName
          else: name & "." & fieldName

        collect(program, childName, fieldValue, locations)

    else:
      {.error: "Unsupported uniform type: " & $T.}

  for name, field in value.fieldPairs:
    collect(program, name, field, result)
