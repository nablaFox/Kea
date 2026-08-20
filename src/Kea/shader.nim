import mesh, math, std/macros

const VertexHeader = """
#version 330 core
#extension GL_ARB_bindless_texture : enable

// attribute locations
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 color;
layout (location = 3) in vec2 uv;

// default input
uniform mat4 model;
uniform mat3 nmat;
"""

const FragHeader = """
#version 330 core
#extension GL_ARB_bindless_texture : enable
"""

type 
  VertShader*[G, M, O: tuple] = proc(
    vertex: Vertex,
    model: Mat4,
    nmat: Mat3,
    material: M,
    globals: G,
    position: var Vec4,
    output: var O
  )

  FragShader*[G, M, I, A: tuple] = proc(
    material: M,
    globals: G,
    input: I,
    atts: var A
  )

proc implementation(shader: NimNode): NimNode {.compileTime.} =
  case shader.kind
  of nnkLambda:
    result = shader

  of nnkSym:
    result = shader.getImpl

    if result.kind notin {nnkProcDef, nnkFuncDef}:
      error("expected a procedure, not a procedure variable", shader)

  else:
    error("expected a named or anonymous procedure", shader)

macro glsl*[G, M, O](shader: VertShader[G, M, O]): string =
  discard shader.implementation
  newStrLitNode ""

macro glsl*[G, M, I, A](shader: FragShader[G, M, I, A]): string =
  discard shader.implementation
  newStrLitNode ""
