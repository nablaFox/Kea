import nimgl/opengl, math, texture

type
  Program* = distinct GLuint

  Uniform* = object
    location: GLint
    glType: GLenum

proc new*(vert: string, frag: string): Program =
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

  let vertexShader = compile(GL_VERTEX_SHADER, vert)
  let fragmentShader = compile(GL_FRAGMENT_SHADER, frag)

  let program = glCreateProgram()

  glAttachShader(program, vertexShader)
  glAttachShader(program, fragmentShader)
  glLinkProgram(program)

  var success: GLint
  glGetProgramiv(program, GL_LINK_STATUS, addr success)

  if success == 0:
    var log = newString(512)
    glGetProgramInfoLog(program, 512, nil, log.cstring)
    quit("Shader linking failed:\n" & log)

  glDeleteShader(vertexShader)
  glDeleteShader(fragmentShader)

  result = Program(program)

proc id*(program: Program): GLuint {.inline.} =
  program.GLuint

proc use*(program: Program) =
  glUseProgram(program.id)

proc destroy*(program: var Program) =
  if not program.id == 0:
    glDeleteProgram(program.id)
    program = Program(0)

template glTypeOf(T: typedesc): GLenum =
  when T is uint32:
    GL_UNSIGNED_INT
  elif T is float32:
    EGL_FLOAT
  elif T is Vec2:
    GL_FLOAT_VEC2
  elif T is Vec3:
    GL_FLOAT_VEC3
  elif T is Vec4:
    GL_FLOAT_VEC4
  elif T is Mat3:
    GL_FLOAT_MAT3
  elif T is Mat4:
    GL_FLOAT_MAT4
  else:
    {.error: "Unsupported uniform type: " & $T.}

template checkType(uniform: Uniform, value: typed) =
  when not defined(release) and not defined(danger):
    if uniform.location >= 0:
      doAssert uniform.glType == glTypeOf(typeof(value))

proc uniform*(program: Program, name: string): Uniform =
  let id = GLuint(program)

  result.location = glGetUniformLocation(id, name.cstring)

  if result.location < 0:
    return

  var cName = name.cstring
  var index: GLuint

  glGetUniformIndices(
    id,
    1,
    addr cName,
    addr index
  )

  if index == GL_INVALID_INDEX:
    return

  var glType: GLint

  glGetActiveUniformsiv(
    id,
    1,
    addr index,
    GL_UNIFORM_TYPE,
    addr glType
  )

  result.glType = GLenum(glType.uint32)

proc set*(uniform: Uniform, value: uint32) =
  checkType(uniform, value)
  glUniform1ui(uniform.location, value.GLuint)

proc set*(uniform: Uniform, value: float32) =
  checkType(uniform, value)
  glUniform1f(uniform.location, value)

proc set*(uniform: Uniform, value: Vec2) =
  checkType(uniform, value)
  glUniform2fv(uniform.location, 1, addr value[0])

proc set*(uniform: Uniform, value: Vec3) =
  checkType(uniform, value)
  glUniform3fv(uniform.location, 1, addr value[0])

proc set*(uniform: Uniform, value: Vec4) =
  checkType(uniform, value)
  glUniform4fv(uniform.location, 1, addr value[0])

proc set*(uniform: Uniform, value: Mat4) =
  checkType(uniform, value)
  glUniformMatrix4fv(uniform.location, 1, true, addr value[0][0])

proc set*(uniform: Uniform, value: Mat3) = 
  checkType(uniform, value)
  glUniformMatrix3fv(uniform.location, 1, true, addr value[0][0]) 

proc setTexture[F: static TextureFormat](
  uniform: Uniform,
  texture: Texture[F]
) =
  if uniform.location < 0:
    return

  when not defined(release) and not defined(danger):
    when F in {Rgba8Linear, R32Float, Rg32Float, Rgba32Float}:
      doAssert (
        uniform.glType == GL_SAMPLER_2D or
        uniform.glType == GL_IMAGE_2D
      )
    else:
      doAssert uniform.glType == GL_SAMPLER_2D

  case uniform.glType
  of GL_SAMPLER_2D:
    glUniformHandleui64ARB(
      uniform.location,
      texture.residentSampleHandle
    )

  of GL_IMAGE_2D:
    when F in {Rgba8Linear, R32Float, Rg32Float, Rgba32Float}:
      glUniformHandleui64ARB(
        uniform.location,
        texture.residentImageHandle
      )
    else:
      raiseAssert "Texture format cannot be used as image2D"

  else:
    raiseAssert "Unsupported uniform type for texture: " & $uniform.glType.uint32

proc set*[F: static TextureFormat](
  uniform: Uniform,
  texture: Texture[F]
) =
  uniform.setTexture(texture)

proc set*[T: tuple](uniforms: openArray[Uniform], values: T) =
  var index = 0

  proc helper[U](
    uniforms: openArray[Uniform],
    value: U,
    index: var int,
  ) =
    when compiles Uniform().set(value):
      uniforms[index].set(value)
      inc index

    elif U is tuple or U is object:
      for _, field in value.fieldPairs:
        helper(uniforms, field, index)

    else:
      {.error: "Unsupported uniform type: " & $U.}

  helper(uniforms, values, index)

proc uniforms*[T: tuple](program: Program): seq[Uniform] =
  var value: T

  proc collect[U](
    program: Program,
    name: string,
    value: U,
    uniforms: var seq[Uniform],
  ) =
    when compiles Uniform().set(value):
      uniforms.add program.uniform(name)

    elif U is tuple or U is object:
      for fieldName, fieldValue in value.fieldPairs:
        let childName =
          if name.len == 0:
            fieldName
          else:
            name & "." & fieldName

        collect(program, childName, fieldValue, uniforms)

    else:
      {.error: "Unsupported uniform type: " & $U.}

  for name, field in value.fieldPairs:
    collect(program, name, field, result)
