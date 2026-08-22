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

func implementation(shader: NimNode): NimNode =
  case shader.kind
  of nnkLambda:
    result = shader

  of nnkSym:
    result = shader.getImpl

    if result.kind notin {nnkProcDef, nnkFuncDef}:
      error("expected a procedure, not a procedure variable", shader)

  else:
    error("expected a named or anonymous procedure", shader)

func materialType*(
  vert, frag: NimNode,
  globals: NimNode
): NimNode =
  let
    vertParams = vert.implementation.params
    fragParams = frag.implementation.params
    vertOutput = vertParams[0]
    globalsType = globals.getTypeImpl
    VertexType = bindSym"Vertex"

  iterator fields(node: NimNode): tuple[name, typ: NimNode] =
    for field in node:
      if field.kind == nnkIdentDefs:
        for i in 0 ..< field.len - 2:
          yield (field[i], field[^2])

  proc containsField(tupleType, name: NimNode): bool =
    for fieldName, _ in tupleType.fields:
      if fieldName.strVal == name.strVal:
        return true

  proc addMaterials(
    material: var NimNode,
    params: NimNode
  ) =
    for name, typ in params.fields:
      if sameType(typ, VertexType):
        continue

      if name.strVal in ["model", "nmat"]:
        continue

      if globalsType.containsField(name) or
         vertOutput.containsField(name) or
         material.containsField(name):
        continue

      material.add newIdentDefs(
        name.strVal.ident,
        typ.copyNimTree
      )

  result = newNimNode(nnkTupleTy)
  result.addMaterials(vertParams)
  result.addMaterials(fragParams)

func attachmentsType*(frag: NimNode): NimNode =
  frag.implementation.params[0]

macro vertGlsl*(shader: typed): string =
  newStrLitNode VertexHeader & ""

macro fragGlsl*(shader: typed): string =
  newStrLitNode FragHeader & ""
