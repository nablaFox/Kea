import mesh, texture, math, std/[macros, strutils]

const VertexHeader* = """
#version 330 core
#extension GL_ARB_bindless_texture : enable

layout (location = 0) in vec3 vertPosition;
layout (location = 1) in vec3 vertNormal;
layout (location = 2) in vec3 vertColor;
layout (location = 3) in vec2 vertUv;

uniform mat4 model;
uniform mat3 nmat;

"""

const FragmentHeader* = """
#version 330 core
#extension GL_ARB_bindless_texture : enable

"""

type
  Parameter = tuple[
    name: NimNode,
    typ: NimNode
  ]

  Signature = object
    returnType: NimNode
    parameters: seq[Parameter]

iterator fields(node: NimNode): Parameter =
  for definition in node:
    if definition.kind == nnkIdentDefs:
      for index in 0 ..< definition.len - 2:
        yield (
          name: definition[index],
          typ: definition[^2]
        )

func implementation(shader: NimNode): NimNode =
  case shader.kind
  of nnkLambda:
    result = shader

  of nnkSym:
    result = shader.getImpl

    if result.kind notin {nnkProcDef, nnkFuncDef}:
      error "expected a procedure, not a procedure variable", shader

  else:
    error "expected a named or anonymous procedure", shader

func fieldType(tupleType, name: NimNode): NimNode =
  for field in tupleType.fields:
    if field.name.strVal == name.strVal:
      return field.typ

func containsField(tupleType, name: NimNode): bool =
  not tupleType.fieldType(name).isNil

proc signature(routine: NimNode): Signature =
  let params = routine.implementation.params

  result.returnType = params[0]

  for field in params.fields:
    result.parameters.add field

proc rootTypes(signature: Signature): seq[NimNode] =
  if signature.returnType.kind != nnkEmpty:
    result.add signature.returnType

  for param in signature.parameters:
    result.add param.typ

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

  proc addMaterials(material: var NimNode, params: NimNode) =
    for field in params.fields:
      if sameType(field.typ, VertexType):
        continue

      if field.name.strVal in ["model", "nmat"]:
        continue

      if globalsType.containsField(field.name) or
         vertOutput.containsField(field.name) or
         material.containsField(field.name):
        continue

      material.add newIdentDefs(
        field.name.strVal.ident,
        field.typ.copyNimTree
      )

  result = newNimNode(nnkTupleTy)
  result.addMaterials(vertParams)
  result.addMaterials(fragParams)

func attachmentsType*(frag: NimNode): NimNode =
  frag.implementation.params[0]

proc glslType(typ: NimNode): string =
  # TODO: handle textures

  let name = typ.repr

  case name
  of "float32": "float"
  of "Vec2": "vec2"
  of "Vec3", "Color": "vec3"
  of "Vec4": "vec4"
  of "Mat3": "mat3"
  of "Mat4": "mat4"
  else: name

proc declaration(typ: NimNode, name: string): string =
  # TODO: handle arrays
  typ.glslType & " " & name & ";\n"

proc structTypes(roots: openArray[NimNode]): seq[NimNode] =
  var
    visited: seq[NimNode]
    structs: seq[NimNode]

  proc isGlslLeafType(typ: NimNode): bool =
    for knownType in [
      bindSym"Vertex",
      bindSym"float32",
      bindSym"Vec2",
      bindSym"Vec3",
      bindSym"Vec4",
      bindSym"Mat3",
      bindSym"Mat4"
    ]:
      if sameType(typ, knownType):
        return true

  proc isTextureType(typ: NimNode): bool =
    typ.kind == nnkBracketExpr and
    typ[0].eqIdent(bindSym"Texture")

  proc wasVisited(typ: NimNode): bool =
    for visitedType in visited:
      if sameType(typ, visitedType):
        return true

  proc visit(typ: NimNode)

  proc visitFields(node: NimNode) =
    case node.kind
    of nnkIdentDefs:
      visit node[^2]

    of nnkRecCase:
      error "variant objects are not supported in shaders", node

    else:
      for child in node:
        visitFields child

  proc visit(typ: NimNode) =
    if typ.isGlslLeafType or typ.isTextureType:
      return

    if typ.wasVisited:
      return

    visited.add typ

    let impl = typ.getTypeImpl

    case impl.kind
    of nnkTupleTy:
      visitFields impl

    of nnkObjectTy:
      if impl[1].kind != nnkEmpty:
        error "object inheritance is not supported in shaders", typ

      visitFields impl[^1]
      structs.add typ

    of nnkBracketExpr:
      if impl[0].eqIdent("array"):
        visit impl[^1]
      else:
        error "unsupported generic shader type: " & typ.repr, typ

    else:
      error "unsupported shader type: " & typ.repr, typ

  for root in roots:
    visit root

  result = structs

proc emitStructDefs(structs: openArray[NimNode]): string =
  for typ in structs:
    let impl = typ.getTypeImpl

    result.add "struct " & typ.repr & " {\n"

    for field in impl[^1].fields:
      result.add "  " & declaration(field.typ, field.name.strVal)

    result.add "};\n\n"

proc precedence(operator: string): int=
  case operator:
  of "+", "-": 1
  of "*", "/": 2
  else: 0

proc emitExpr(
  node: NimNode, 
  parentPrecedence = 0,
  isRightOperand = false
): string =
  case node.kind
  of nnkIdent, nnkSym:
    result = node.strVal

  of nnkDotExpr:
    let field = node[1].strVal

    result =
      if node[0].eqIdent("result"):
        if field == "pos": "gl_Position"
        else: field
      elif sameType(node[0].getTypeImpl, bindSym"Vertex"):
        "vert" & field.capitalizeAscii
      else:
        node[0].emitExpr & "." & field

  of nnkCall:
    if node[0].eqIdent("hom"):
      if node.len != 3:
        error "hom expects two arguments", node

      result =
        "vec4(" &
        node[1].emitExpr & ", " &
        node[2].emitExpr & ")"

  of nnkStmtListExpr:
    for index in 0 ..< node.len - 1:
      if node[index].kind != nnkEmpty:
        error "statements inside expressions are not supported yet", node

    result = node[^1].emitExpr

  of nnkBracketExpr:
    result =
      node[0].emitExpr & "[" &
      node[1].emitExpr & "]"

  of nnkInfix:
    let 
      operator = node[0].strVal
      precedence = operator.precedence

    result = 
      node[1].emitExpr(precedence, false) & " " &
      operator & " " &
      node[2].emitExpr(precedence, true)

    if precedence < parentPrecedence or
      (precedence == parentPrecedence and isRightOperand):
      result = "(" & result & ")"

  of nnkPrefix:
    result = node[0].strVal & node[1].emitExpr

  of nnkIfExpr:
    result = node[0].emitExpr & " : " & node[1].emitExpr

  of nnkElifExpr:
    result = node[0].emitExpr & " ? " & node[1].emitExpr

  of nnkElseExpr:
    result = node[0].emitExpr
      
  of nnkHiddenStdConv, nnkHiddenSubConv:
    result = node[^1].emitExpr(parentPrecedence, isRightOperand)

  of nnkFloatLit..nnkFloat64Lit:
    result = node.repr

  of nnkIntLit..nnkUInt64Lit:
    result = $node.intVal

  else:
    echo(
      "unsupported expression: " &
      $node.kind & ":\n" &
      node.treeRepr
    )

proc emitStmt(node: NimNode): string =
  case node.kind
  of nnkStmtList:
    for statement in node:
      result.add statement.emitStmt

  of nnkAsgn:
    result.add(
      "  " &
      node[0].emitExpr & " = " &
      node[1].emitExpr & ";\n"
    )

  else:
    discard

proc emitMain(shader: NimNode): string =
  let body = shader.implementation.body

  result = "void main() {\n"
  result.add body.emitStmt
  result.add "}\n"

proc vertGlslImpl*(shader: NimNode): string =
  let signature = shader.signature

  if signature.returnType.kind != nnkTupleTy:
    error "vertex shader must return a tuple", shader

  let structs = block:
    var roots: seq[NimNode]

    roots.add signature.rootTypes

    # TODO: add roots of helpers
    # TODO: add local types

    roots.structTypes

  result = VertexHeader
  result.add structs.emitStructDefs

  for field in signature.returnType.fields:
    if field.name.strVal == "pos":
      continue

    result.add "out " & declaration(field.typ, field.name.strVal)

  for param in signature.parameters:
    if sameType(param.typ, bindSym"Vertex"):
      continue

    if param.name.strVal in ["model", "nmat"]:
      continue

    # TODO: handle undefined types

    result.add "uniform " & declaration(param.typ, param.name.strVal)

  result.add shader.emitMain

proc fragGlslImpl*(vert, frag: NimNode): string =
  let
    signature = frag.signature
    returnType = signature.returnType
    vertReturnType = vert.signature.returnType

  if returnType.kind != nnkTupleTy:
    error "fragment shader must return a tuple", frag

  let structs = block:
    var roots: seq[NimNode]

    roots.add signature.rootTypes

    # TODO: add roots of helpers
    # TODO: add local types

    roots.structTypes

  result = FragmentHeader
  result.add structs.emitStructDefs

  var location = 0

  for field in returnType.fields:
    result.add(
      "layout (location = " & $location & ") out " &
      declaration(field.typ, field.name.strVal)
    )

    inc location

  for param in signature.parameters:
    let
      name = param.name.strVal
      varyingType = vertReturnType.fieldType(param.name)
      isVarying = name != "pos" and not varyingType.isNil

    if isVarying and not sameType(param.typ, varyingType):
      error(
        "fragment input '" & name &
        "' has type " & param.typ.repr &
        ", but vertex output has type " & varyingType.repr,
        param.name
      )

    let qualifier = if isVarying: "in " else: "uniform "

    result.add qualifier & declaration(param.typ, name)

  result.add frag.emitMain

macro vertGlsl*(shader: typed): string =
  newStrLitNode vertGlslImpl(shader)

macro fragGlsl*(vert, frag: typed): string =
  newStrLitNode fragGlslImpl(vert, frag)
