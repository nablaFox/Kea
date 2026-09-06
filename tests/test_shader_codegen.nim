import
  Kea/[shader, math, mesh, colors, texture],
  std/[macros, strutils, unittest]

func normalized(source: string): string =
  for line in source.splitLines:
    let trimmed = line.strip
    if trimmed.len > 0:
      result.add trimmed & "\n"

type
  RectLight* = object
    position*: Vec3
    rotation*: Mat3 = Identity3
    width*: float32 = 1.0
    height*: float32 = 1.0
    radiance*: Vec3

  Lighting = object
    light: RectLight
    ambient: Vec3

  Dimensions = object
    width, height: float32

  HelperInput = object
    value: float32

  LocalValue = object
    value: float32

  EmptyGlobals = tuple[]

  InvalidUniform = object
    name: string

proc positionOnlyVertex(vert: Vertex): tuple[pos: Vec4] =
  result.pos = vert.position.hom

proc shaderDouble(x: float32): float32 =
  x * 2.0

proc shaderQuadruple(x: float32): float32 =
  shaderDouble(shaderDouble(x))

proc unusedShaderHelper(x: float32): float32 =
  x + 1.0

proc shaderExplicitReturn(x: float32): float32 =
  return x * 2.0

proc shaderResultAssignment(x: float32): float32 =
  result = x * 2.0

proc shaderWithLocalStruct(x: float32): float32 =
  var local: LocalValue
  local.value = x
  result = local.value

proc shaderWithStructParameter(input: HelperInput): float32 =
  input.value

proc shaderWithNestedHelper(x: float32): float32 =
  proc innerDouble(value: float32): float32 =
    value * 2.0

  innerDouble(x)


suite "shader source generation":
  test "emits vertex shader header":
    let glsl = vertGlsl(positionOnlyVertex)

    check glsl.startsWith(
      "#version 330 core\n" &
      "#extension GL_ARB_bindless_texture : enable"
    )

    check "layout (location = 0) in vec3 vertPosition;" in glsl
    check "uniform mat4 model;" in glsl
    check "uniform mat3 nmat;" in glsl

  test "emits fragment shader header":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(): tuple[pixel: Vec4] =
        discard
    )

    check glsl.startsWith(
      "#version 330 core\n" &
      "#extension GL_ARB_bindless_texture : enable"
    )


suite "shader type generation":
  test "maps int32 uniforms and outputs":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: int32): tuple[pixel: int32] =
        result.pixel = value
    )

    check "uniform int value;" in glsl
    check "layout (location = 0) out int pixel;" in glsl

  test "maps scalar, vector, and matrix types":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(
        scalar: float32,
        offset: Vec2,
        direction: Vec3,
        value: Vec4,
        rotation: Mat3,
        transform: Mat4
      ): tuple[pixel: Vec4] =
        discard
    )

    check "uniform float scalar;" in glsl
    check "uniform vec2 offset;" in glsl
    check "uniform vec3 direction;" in glsl
    check "uniform vec4 value;" in glsl
    check "uniform mat3 rotation;" in glsl
    check "uniform mat4 transform;" in glsl

  test "maps textures to sampler2D uniforms":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(texture: Texture[R32Float]): tuple[pixel: Vec4] =
        discard
    )

    check "uniform sampler2D texture;" in glsl

  test "declares arrays of scalar uniforms":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(weights: array[5, float32]): tuple[pixel: Vec4] =
        discard
    )

    check "uniform float weights[5];" in glsl

  test "declares arrays of vector uniforms":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(points: array[8, Vec3]): tuple[pixel: Vec4] =
        discard
    )

    check "uniform vec3 points[8];" in glsl

  test "declares object types as GLSL structs":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(light: RectLight): tuple[pixel: Vec4] =
        discard
    )

    let expected = """
      struct RectLight {
        vec3 position;
        mat3 rotation;
        float width;
        float height;
        vec3 radiance;
      };
    """

    check expected.normalized in glsl.normalized

  test "emits struct definitions once":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(
        keyLight: RectLight,
        fillLight: RectLight
      ): tuple[pixel: Vec4] =
        discard
    )

    check glsl.count("struct RectLight {") == 1
    check "uniform RectLight keyLight;" in glsl
    check "uniform RectLight fillLight;" in glsl

  test "emits nested struct dependencies first":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(lighting: Lighting): tuple[pixel: Vec4] =
        discard
    )

    let rectLightPosition = glsl.find("struct RectLight {")
    let lightingPosition = glsl.find("struct Lighting {")

    check rectLightPosition >= 0
    check lightingPosition > rectLightPosition

    check "RectLight light;" in glsl
    check "vec3 ambient;" in glsl
    check "uniform Lighting lighting;" in glsl

  test "emits every grouped object field":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(size: Dimensions): tuple[pixel: float32] =
        discard
    )

    let expected = """
      struct Dimensions {
        float width;
        float height;
      };
    """

    check expected.normalized in glsl.normalized

  test "emits struct definitions in vertex shaders":
    let glsl = vertGlsl(
      proc(vert: Vertex, light: RectLight): tuple[pos: Vec4] =
        result.pos = vert.position.hom
    )

    let structPosition = glsl.find("struct RectLight {")
    let uniformPosition = glsl.find("uniform RectLight light;")

    check structPosition >= 0
    check uniformPosition > structPosition


suite "shader interface generation":
  test "declares vertex tuple fields as outputs":
    let glsl = vertGlsl(
      proc(vert: Vertex): tuple[
        pos: Vec4,
        color: Color,
        uv: Vec2
      ] =
        discard
    )

    check "out vec3 color;" in glsl
    check "out vec2 uv;" in glsl
    check "out vec4 pos;" notin glsl

  test "assigns fragment output locations in tuple order":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(): tuple[color: Vec4, mask: float32] =
        discard
    )

    check "layout (location = 0) out vec4 color;" in glsl
    check "layout (location = 1) out float mask;" in glsl

  test "declares ordinary vertex parameters as uniforms":
    let glsl = vertGlsl(
      proc(vert: Vertex, scale: float32): tuple[pos: Vec4] =
        discard
    )

    check "uniform float scale;" in glsl

  test "classifies unmatched fragment parameter as uniform":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(color: Color): tuple[pixel: Vec4] =
        discard
    )

    check "uniform vec3 color;" in glsl
    check "in vec3 color;" notin glsl

  test "declares object parameters as struct uniforms":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(light: RectLight): tuple[pixel: Vec4] =
        discard
    )

    let structPosition = glsl.find("struct RectLight {")
    let uniformPosition = glsl.find("uniform RectLight light;")

    check structPosition >= 0
    check uniformPosition > structPosition

  test "classifies matching vertex output as fragment input":
    let glsl = fragGlsl(
      proc(vert: Vertex): tuple[
        pos: Vec4,
        color: Color
      ] =
        discard,

      proc(color: Color): tuple[pixel: Vec4] =
        discard
    )

    check "in vec3 color;" in glsl
    check "uniform vec3 color;" notin glsl

  test "uses flat interpolation for integer varyings":
    proc vertex(vert: Vertex, value: int32): tuple[pos: Vec4, category: int32] =
      result.pos = vert.position.hom
      result.category = value

    let
      vs = vertGlsl(vertex)
      fs = fragGlsl(
        vertex,

        proc(category: int32): tuple[pixel: int32] =
          result.pixel = category
      )

    check "flat out int category;" in vs
    check "flat in int category;" in fs

  test "does not expose vertex pos as fragment input":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(pos: Vec4): tuple[pixel: Vec4] =
        result.pixel = pos
    )

    check "in vec4 pos;" notin glsl
    check "uniform vec4 pos;" in glsl

  test "declares every grouped vertex output":
    let glsl = vertGlsl(
      proc(vert: Vertex): tuple[pos: Vec4, first, second: float32] =
        discard
    )

    check "out float first;" in glsl
    check "out float second;" in glsl

  test "assigns separate locations to grouped fragment outputs":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(): tuple[first, second: float32, color: Vec4] =
        discard
    )

    check "layout (location = 0) out float first;" in glsl
    check "layout (location = 1) out float second;" in glsl
    check "layout (location = 2) out vec4 color;" in glsl

  test "does not declare Vertex parameters as uniforms":
    let glsl = vertGlsl(positionOnlyVertex)

    check "uniform Vertex vert;" notin glsl
    check "struct Vertex {" notin glsl

  test "does not duplicate model and nmat uniforms":
    let glsl = vertGlsl(
      proc(vert: Vertex, model: Mat4, nmat: Mat3): tuple[pos: Vec4] =
        discard
    )

    check glsl.count("uniform mat4 model;") == 1
    check glsl.count("uniform mat3 nmat;") == 1

  test "merges matching material fields from both stages":
    macro inferredMaterial(vert, frag: typed): untyped =
      materialType(vert, frag, bindSym"EmptyGlobals")

    type Material = inferredMaterial(
      proc(vert: Vertex, strength: float32): tuple[pos: Vec4] =
        result.pos = vert.position.hom,

      proc(strength: float32): tuple[pixel: float32] =
        result.pixel = strength
    )

    check (Material is tuple[strength: float32])


suite "shader expression generation":
  test "lowers hom intrinsic":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(color: Color): tuple[pixel: Vec4] =
        result.pixel = color.hom
    )

    check "pixel = vec4(color, 1.0);" in glsl
    check "hom(" notin glsl

  test "lowers vector component templates to indexing":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: Vec4): tuple[x, y, z, w: float32] =
        result.x = value.x
        result.y = value.y
        result.z = value.z
        result.w = value.w
    )

    check "x = value[0];" in glsl
    check "y = value[1];" in glsl
    check "z = value[2];" in glsl
    check "w = value[3];" in glsl

  test "emits object field access":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(light: RectLight): tuple[pixel: Vec4] =
        result.pixel = light.position.hom
    )

    check "pixel = vec4(light.position, 1.0);" in glsl

  test "emits arithmetic expressions":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b: float32): tuple[value: float32] =
        result.value = a + b * 2.0
    )

    check "value = a + b * 2.0;" in glsl

  test "preserves required parentheses":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b: float32): tuple[value: float32] =
        result.value = (a + b) * 2.0
    )

    check "value = (a + b) * 2.0;" in glsl

  test "preserves grouping in nested subtraction":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b, c: float32): tuple[pixel: float32] =
        result.pixel = a - (b - c)
    )

    check "pixel = a - (b - c);" in glsl

  test "preserves grouping in division by a product":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b, c: float32): tuple[pixel: float32] =
        result.pixel = a / (b * c)
    )

    check "pixel = a / (b * c);" in glsl

  test "emits unary minus":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = -value
    )

    check "pixel = -value;" in glsl

  test "preserves grouping under unary minus":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b: float32): tuple[sum, negation: float32] =
        result.sum = -(a + b)
        result.negation = -(-a)
    )

    check "sum = -(a + b);" in glsl
    check "negation = -(-a);" in glsl

  test "emits ternary expressions":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel =
          if value >= 0.0: value
          else: -value
    )

    check "pixel = (0.0 <= value ? value : -value);" in glsl

  test "preserves all branches of ternary expressions":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel =
          if value < 0.0: -1.0
          elif value > 0.0: 1.0
          else: 0.0
    )

    check "pixel = (value < 0.0 ? -1.0 : 0.0 < value ? 1.0 : 0.0);" in glsl

  test "emits vector indexing":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: Vec4): tuple[pixel: float32] =
        result.pixel = value[2]
    )

    check "pixel = value[2];" in glsl

  test "preserves grouping before indexing and xyz swizzles":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b: Vec4): tuple[component: float32, color: Vec3] =
        result.component = (a + b)[2]
        result.color = (a + b).xyz
    )

    check "component = (a + b)[2];" in glsl
    check "color = (a + b).xyz;" in glsl
    check "xyz(" notin glsl

  test "emits numeric conversions":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(index: int): tuple[pixel: float32] =
        result.pixel = index.float32
    )

    check "pixel = float(index);" in glsl

  test "emits float32 array literals as vectors":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(): tuple[pixel: Vec4] =
        result.pixel = [1.0'f, 2.0, 0.5, 1.0]
    )

    check "pixel = vec4(1.0, 2.0, 0.5, 1.0);" in glsl

  test "emits nested float32 array literals as matrices":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(): tuple[pixel: float32] =
        let matrix: Mat3 = [
          [1.0'f, 2.0, 3.0],
          [4.0'f, 5.0, 6.0],
          [7.0'f, 8.0, 9.0]
        ]

        result.pixel = matrix[0][1]
    )

    check (
      "mat3 matrix = mat3(" &
      "vec3(1.0, 2.0, 3.0), " &
      "vec3(4.0, 5.0, 6.0), " &
      "vec3(7.0, 8.0, 9.0));"
    ) in glsl

    check "pixel = matrix[0][1];" in glsl


suite "shader body generation":
  test "emits direct assignments":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = value
    )

    check "pixel = value;" in glsl

  test "maps Vertex fields to attributes":
    let glsl = vertGlsl(
      proc(v: Vertex): tuple[
        pos: Vec4,
        normal: Vec3,
        color: Color,
        uv: Vec2
      ] =
        result.pos = v.position.hom
        result.normal = v.normal
        result.color = v.color
        result.uv = v.uv
    )

    check "gl_Position = vec4(vertPosition, 1.0);" in glsl
    check "normal = vertNormal;" in glsl
    check "color = vertColor;" in glsl
    check "uv = vertUv;" in glsl

  test "maps vertex result fields to varyings":
    let glsl = vertGlsl(
      proc(vert: Vertex): tuple[
        pos: Vec4,
        color: Color
      ] =
        result.pos = vert.position.hom
        result.color = vert.color
    )

    check "out vec3 color;" in glsl
    check "color = vertColor;" in glsl

  test "maps fragment result fields to output variables":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b: float32): tuple[first, second: float32] =
        result.first = a
        result.second = b
    )

    check "first = a;" in glsl
    check "second = b;" in glsl
    check "result." notin glsl

  test "emits initialized let declarations":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        let doubled = value * 2.0
        result.pixel = doubled
    )

    check "float doubled = value * 2.0;" in glsl
    check "pixel = doubled;" in glsl

  test "emits multiple let bindings with different types":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(): tuple[
        pixel: Vec4
      ] =
        let
          intensity = 1.0'f
          count = 2
          uv = [3.0'f, 2.0]

        result.pixel = [intensity, count.float32, uv.x, uv.y]
    )

    check "float intensity = 1.0;" in glsl
    check "int count = 2;" in glsl
    check "vec2 uv = vec2(3.0, 2.0);" in glsl
    check "pixel = vec4(intensity, float(count), uv[0], uv[1])" in glsl

  test "emits comparison and boolean operators":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value, lower, upper: float32): tuple[pixel: float32] =
        if value >= lower and value <= upper:
          result.pixel = value
    )

    check "if (lower <= value && value <= upper) {" in glsl

  test "preserves grouping between boolean operators":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b, c: float32): tuple[pixel: float32] =
        if (a < 0.0 or b < 0.0) and c < 0.0:
          result.pixel = 1.0
    )

    check "if ((a < 0.0 || b < 0.0) && c < 0.0) {" in glsl

  test "lowers boolean negation and preserves its operand":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b: float32): tuple[pixel: float32] =
        if not (a < 0.0 or b < 0.0):
          result.pixel = 1.0
    )

    check "if (!(a < 0.0 || b < 0.0)) {" in glsl

  test "emits if else control flow":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        if value > 0.0:
          result.pixel = value
        else:
          result.pixel = 0.0
    )

    check """
      if (0.0 < value) {
        pixel = value;
      } else {
        pixel = 0.0;
      }
    """.normalized in glsl.normalized

  test "emits elif branches":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        if value < 0.0:
          result.pixel = -1.0
        elif value > 0.0:
          result.pixel = 1.0
        else:
          result.pixel = 0.0
    )

    check "if (value < 0.0) {" in glsl
    check "} else if (0.0 < value) {" in glsl
    check "} else {" in glsl

  test "emits compound assignments":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        var total = value
        total += value
        total -= value
        total *= value
        total /= value
        result.pixel = total
    )

    let expected = """
      total += value;
      total -= value;
      total *= value;
      total /= value;
    """

    check expected.normalized in glsl.normalized

  test "emits exclusive range for loops":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        var total = 0.0'f

        for i in 0 ..< 4:
          total += value

        result.pixel = total
    )

    check "for (int i = 0; i < 4; ++i) {" in glsl
    check "total += value;" in glsl

  test "emits inclusive range for loops":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        var total = 0.0'f

        for i in 0 .. 4:
          total += value

        result.pixel = total
    )

    check "for (int i = 0; i <= 4; ++i) {" in glsl

  test "emits mutable local declarations and reassignment":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        var doubled = value
        doubled = doubled * 2.0
        result.pixel = doubled
    )

    let declarationPosition = glsl.find("float doubled = value;")
    let assignmentPosition = glsl.find("doubled = doubled * 2.0;")
    let outputPosition = glsl.find("pixel = doubled;")

    check declarationPosition >= 0
    check assignmentPosition > declarationPosition
    check outputPosition > assignmentPosition

    test "emits statement expressions directly into assignment targets":
      let glsl = fragGlsl(
        positionOnlyVertex,

        proc(value: float32): tuple[pixel: float32] =
          result.pixel =
            if value < 0.0:
              let magnitude = -value
              magnitude * 2.0
            else:
              let doubled = value * 2.0
              doubled + 1.0
      )

      check "if (value < 0.0) {" in glsl
      check "float magnitude = -value;" in glsl
      check "pixel = magnitude * 2.0;" in glsl

      check "} else {" in glsl
      check "float doubled = value * 2.0;" in glsl
      check "pixel = doubled + 1.0;" in glsl

      check "keaTemp" notin glsl


suite "shader helper generation":
  test "preserves calls whose return values are discarded":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        discard shaderDouble(value)
        result.pixel = value
    )

    check "shaderDouble(value);" in glsl
    check "pixel = value;" in glsl

  test "emits used helper functions once":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(a, b: float32): tuple[first, second: float32] =
        result.first = shaderDouble(a)
        result.second = shaderDouble(b)
    )

    check glsl.count("float shaderDouble(") == 1
    check "first = shaderDouble(a);" in glsl
    check "second = shaderDouble(b);" in glsl

  test "emits helper dependencies before their callers":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = shaderQuadruple(value)
    )

    let doublePosition = glsl.find("float shaderDouble(")
    let quadruplePosition = glsl.find("float shaderQuadruple(")

    check doublePosition >= 0
    check quadruplePosition > doublePosition
    check glsl.count("float shaderDouble(") == 1
    check "pixel = shaderQuadruple(value);" in glsl

  test "emits helpers called with UFCS syntax":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = value.shaderDouble
    )

    check "float shaderDouble(float x) {" in glsl
    check "result = x * 2.0;" in glsl
    check "return result;" in glsl
    check "pixel = shaderDouble(value);" in glsl

  test "does not emit unused helper functions":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = value
    )

    check "unusedShaderHelper" notin glsl

  test "emits explicit helper returns":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = shaderExplicitReturn(value)
    )

    check "float shaderExplicitReturn(float x) {" in glsl
    check "result = x * 2.0;" in glsl
    check "return result;" in glsl
    check "pixel = shaderExplicitReturn(value);" in glsl

  test "emits helper result assignments":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = shaderResultAssignment(value)
    )

    check "float shaderResultAssignment(float x) {" in glsl
    check (
      "return x * 2.0;" in glsl or
      ("float result" in glsl and
       "result = x * 2.0;" in glsl and
       "return result;" in glsl)
    )
    check "pixel = shaderResultAssignment(value);" in glsl

  test "declares structs before helpers that use them":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(): tuple[pixel: float32] =
        var input: HelperInput
        result.pixel = shaderWithStructParameter(input)
    )

    let structPosition = glsl.find("struct HelperInput {")
    let helperPosition = glsl.find("float shaderWithStructParameter(")

    check structPosition >= 0
    check helperPosition > structPosition

  test "discovers structs used only in helper locals":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = shaderWithLocalStruct(value)
    )

    let structPosition = glsl.find("struct LocalValue {")
    let helperPosition = glsl.find("float shaderWithLocalStruct(")

    check structPosition >= 0
    check helperPosition > structPosition
    check "LocalValue local" in glsl

  test "emits helpers defined inside the shader":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        proc innerDouble(x: float32): float32 =
          x * 2.0

        result.pixel = innerDouble(value)
    )

    let helperPosition = glsl.find("float innerDouble(float x) {")
    let mainPosition = glsl.find("void main() {")

    check helperPosition >= 0
    check mainPosition > helperPosition
    check glsl.count("float innerDouble(") == 1
    check "result = x * 2.0;" in glsl
    check "pixel = innerDouble(value);" in glsl

  test "emits helpers defined inside helpers":
    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = shaderWithNestedHelper(value)
    )

    let
      innerPosition = glsl.find("float innerDouble(float value) {")
      outerPosition = glsl.find("float shaderWithNestedHelper(float x) {")
      mainPosition = glsl.find("void main() {")

    check innerPosition >= 0
    check outerPosition > innerPosition
    check mainPosition > outerPosition
    check glsl.count("float innerDouble(") == 1
    check glsl.count("float shaderWithNestedHelper(") == 1
    check "result = innerDouble(x);" in glsl
    check "pixel = shaderWithNestedHelper(value);" in glsl

  test "emits helper bodies directly into implicit result":
    proc helperWithEarlyReturn(value: float32): float32 =
      let doubled = value * 2.0

      if doubled < 0.0:
        return 0.0

      max(doubled, 1.0)

    let glsl = fragGlsl(
      positionOnlyVertex,

      proc(value: float32): tuple[pixel: float32] =
        result.pixel = helperWithEarlyReturn(value)
    )

    check "float doubled = value * 2.0;" in glsl
    check "result = 0.0;" in glsl
    check "result = max(doubled, 1.0);" in glsl
    check "keaTemp" notin glsl

suite "complete shader generation":
  test "generates position-only vertex shader":
    let expected = VertexHeader & """
      void main() {
        gl_Position = vec4(vertPosition, 1.0);
      }
    """

    let named = vertGlsl(positionOnlyVertex)

    let anonymous = vertGlsl(
      proc(vert: Vertex): tuple[pos: Vec4] =
        result.pos = vert.position.hom
    )

    check named.normalized == expected.normalized
    check anonymous.normalized == expected.normalized

  test "generates fragment shader with color uniform":
    let expected = FragmentHeader & """
      layout (location = 0) out vec4 pixel;

      uniform vec3 color;

      void main() {
        pixel = vec4(color, 1.0);
      }
    """

    let actual = fragGlsl(
      positionOnlyVertex,

      proc(color: Color): tuple[pixel: Vec4] =
        result.pixel = color.hom
    )

    check actual.normalized == expected.normalized


suite "shader validation":
  test "rejects unsupported expressions instead of emitting empty code":
    check not compiles(
      fragGlsl(
        positionOnlyVertex,

        proc(value: float32): tuple[pixel: float32] =
          result.pixel = shaderWithStructParameter(HelperInput(value: value))
      )
    )

  test "rejects non-tuple vertex output":
    check not compiles(
      vertGlsl(
        proc(vert: Vertex): Vec4 =
          vert.position.hom
      )
    )

  test "rejects vertex output without pos":
    check not compiles(
      vertGlsl(
        proc(vert: Vertex): tuple[color: Color] =
          result.color = vert.color
      )
    )

  test "rejects pos with non-Vec4 type":
    check not compiles(
      vertGlsl(
        proc(vert: Vertex): tuple[pos: Vec3] =
          result.pos = vert.position
      )
    )

  test "rejects non-tuple fragment output":
    check not compiles(
      fragGlsl(
        positionOnlyVertex,

        proc(color: Color): Vec4 =
          color.hom
      )
    )

  test "rejects pos field in fragment output":
    check not compiles(
      fragGlsl(
        positionOnlyVertex,

        proc(): tuple[pos: Vec4] =
          result.pos = vec4(1.0)
      )
    )

  test "rejects mismatched varying types":
    check not compiles(
      fragGlsl(
        proc(vert: Vertex): tuple[
          pos: Vec4,
          color: Color
        ] =
          discard,

        proc(color: Vec4): tuple[pixel: Vec4] =
          discard
      )
    )

  test "rejects conflicting material field types":
    check not compiles(
      fragGlsl(
        proc(vert: Vertex, strength: float32): tuple[pos: Vec4] =
          result.pos = vert.position.hom,

        proc(strength: Vec2): tuple[pixel: Vec4] =
          discard
      )
    )

  test "rejects unsupported object field types":
    check not compiles(
      fragGlsl(
        positionOnlyVertex,

        proc(value: InvalidUniform): tuple[pixel: Vec4] =
          discard
      )
    )
