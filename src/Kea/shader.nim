import
  math,
  texture,
  colors,
  std/[macros, sequtils, strutils, math]

const
  VertexHeader* = """
    #version 330 core
    #extension GL_ARB_bindless_texture : enable

    layout (location = 0) in vec3 vertPosition;
    layout (location = 1) in vec3 vertNormal;
    layout (location = 2) in vec3 vertColor;
    layout (location = 3) in vec2 vertUv;

    uniform mat4 model;
    uniform mat3 nmat;
  """

  FragmentHeader* = """
    #version 330 core
    #extension GL_ARB_bindless_texture : enable
    layout(bindless_sampler) uniform;
  """

type
  Vertex* = object
    position*: Vec3
    normal*: Vec3
    color*: Vec3
    uv*: Vec2

  Parameter = tuple[name, typ: NimNode]

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

func signature(routine: NimNode): Signature =
  let params = routine.implementation.params

  result.returnType = params[0]

  if result.returnType.kind != nnkEmpty:
    let impl = result.returnType.getTypeImpl

    if impl.kind == nnkTupleTy:
      result.returnType = impl

  result.parameters = params.fields.toSeq

proc rootTypes(signature: Signature): seq[NimNode] =
  if signature.returnType.kind != nnkEmpty:
    result.add signature.returnType

  for param in signature.parameters:
    result.add param.typ

proc localTypes(body: NimNode): seq[NimNode] =
  var types: seq[NimNode]

  proc visit(node: NimNode) =
    case node.kind
    of nnkProcDef, nnkFuncDef, nnkLambda:
      return

    of nnkLetSection, nnkVarSection:
      for definition in node:
        if definition.kind == nnkIdentDefs:
          for index in 0 ..< definition.len - 2:
            types.add definition[index].getTypeInst

    else:
      discard

    for child in node:
      visit child

  visit body

  types

proc isTextureType(typ: NimNode): bool =
  let typ = typ.getTypeInst

  typ.kind == nnkBracketExpr and
  typ[0].eqIdent("Texture")

proc glslBuiltinType(typ: NimNode): string =
  for (nimType, glslName) in [
    (bindSym"bool", "bool"),
    (bindSym"float32", "float"),
    (bindSym"float64", "float"),
    (bindSym"int", "int"),
    (bindSym"uint32", "uint"),
    (bindSym"int32", "int"),
    (bindSym"Vec2", "vec2"),
    (bindSym"Vec3", "vec3"),
    (bindSym"Vec4", "vec4"),
    (bindSym"Mat3", "mat3"),
    (bindSym"Mat4", "mat4")
  ]:
    if sameType(typ, nimType):
      return glslName

  let impl = typ.getTypeImpl

  if impl.kind != nnkBracketExpr or not impl[0].eqIdent("array"):
    return ""

  let bounds = impl[1]

  if bounds.kind != nnkInfix or not bounds[0].eqIdent(".."):
    return ""

  let
    length = bounds[2].intVal - bounds[1].intVal + 1
    element = impl[^1].glslBuiltinType

  if length in 2 .. 4 and element == "float":
    result = "vec" & $length

  elif length in 3 .. 4 and element == "vec" & $length:
    result = "mat" & $length

proc arrayLength(impl: NimNode): int =
  let bounds = impl[1]

  if bounds.kind != nnkInfix or not bounds[0].eqIdent(".."):
    error "shader arrays require a constant integer range", impl

  let
    first = bounds[1].intVal
    last = bounds[2].intVal

  if first != 0 or last < first:
    error "shader arrays must be nonempty and zero-indexed", impl

  int(last - first + 1)

proc glslType(typ: NimNode): string =
  result = typ.glslBuiltinType

  if result.len > 0:
    return

  if typ.isTextureType:
    return "sampler2D"

  let impl = typ.getTypeImpl

  if impl.kind == nnkBracketExpr and impl[0].eqIdent("array"):
    let
      length = impl.arrayLength
      elementType = impl[^1].glslType

    if elementType.endsWith("]"):
      error "arrays of arrays require a newer GLSL version", typ

    return elementType & "[" & $length & "]"

  if impl.kind == nnkObjectTy:
    return typ.repr

  error "unsupported shader type: " & typ.repr, typ

proc glslOperator(operator: NimNode): string =
  case operator.strVal:
  of "+", "-", "*", "/", "+=", "-=",
     "*=", "/=", "<=", ">=", "<", ">",
     "!=", "==":
    operator.strVal
  of "and": "&&"
  of "or": "||"
  of "not": "!"
  of "mod": "%"
  else:
    error "unsupported shader operator: " & operator.strVal, operator

proc precedence(operator: string): int =
  case operator:
  of "||": 1
  of "&&": 2
  of "<=", ">=", ">", "<", "!=", "==": 3
  of "+", "-": 4
  of "*", "/", "%": 5
  else: 0

proc precedence(node: NimNode): int =
  case node.kind
  of nnkInfix:
    node[0].glslOperator.precedence
  of nnkPrefix:
    6
  of nnkFloatLit..nnkFloat64Lit:
    if node.floatVal < 0: 6 else: 7
  of nnkIntLit..nnkUInt64Lit:
    if node.intVal < 0: 6 else: 7
  else:
    7

proc declaration(typ: NimNode, name: string): string =
  let
    typeName = typ.glslType
    arrayStart = typeName.find('[')

  if arrayStart >= 0:
    return typeName[0 ..< arrayStart] & " " & name &
      typeName[arrayStart .. ^1] & ";\n"

  typeName & " " & name & ";\n"

proc structTypes(roots: openArray[NimNode]): seq[NimNode] =
  var
    visited: seq[NimNode]
    structs: seq[NimNode]

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
    if sameType(typ, bindSym"Vertex") or typ.isTextureType or
       typ.glslBuiltinType.len > 0:
      return

    if visited.anyIt(sameType(it, typ)):
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

  structs

proc emitUsedStructs(
  shader: NimNode,
  helpers: openArray[NimNode]
): string =
  proc emitStructDef(struct: NimNode): string =
    let impl = struct.getTypeImpl

    result.add "struct " & struct.repr & " {\n"

    for field in impl[^1].fields:
      result.add "  " &
        declaration(field.typ, field.name.strVal)

    result.add "};\n\n"

  var roots: seq[NimNode]

  roots.add shader.signature.rootTypes

  roots.add shader.implementation.body.localTypes

  for helper in helpers:
    roots.add helper.signature.rootTypes
    roots.add helper.implementation.body.localTypes

  result.add "\n" & roots
    .structTypes
    .mapIt(it.emitStructDef)
    .join("\n")

proc intrinsicName(symbol: NimNode): string =
  if symbol.kind != nnkSym:
    return ""

  if symbol.symKind notin {nskProc, nskFunc}:
    return ""

  proc matches(intrinsic: NimNode): bool =
    symbol == intrinsic or
    symbol.isInstantiationOf(intrinsic)

  for (intrinsic, name) in [
    (bindSym"hom", "vec4"),
    (bindSym"xyz", ".xyz"),
    (bindSym"xy", ".xy"),
    (bindSym"sample", "texture"),
    (bindSym"normalize", "normalize"),
    (bindSym"dot", "dot"),
    (bindSym"pow", "pow"),
    (bindSym"clamp", "clamp"),
    (bindSym"sqrt", "sqrt"),
    (bindSym"invsqrt", "inversesqrt"),
    (bindSym"vec", "vec"),
    (bindSym"vec3", "vec3"),
    (bindSym"mix", "mix"),
    (bindSym"size", "textureSize"),
    (bindSym"abs", "abs"),
    (bindSym"max", "max"),
    (bindSym"min", "min"),
    (bindSym"cross", "cross"),
    (bindSym"transpose", "transpose"),
    (bindSym"floorMod", "mod"),
  ]:
    if intrinsic.kind in {nnkOpenSymChoice, nnkClosedSymChoice}:
      for overload in intrinsic:
        if matches(overload):
          return name

    elif matches(intrinsic):
      return name

proc containsGenericParameter(node: NimNode): bool =
  if node.kind == nnkSym and node.symKind == nskGenericParam:
    return true

  for child in node:
    if child.containsGenericParameter:
      return true

proc helpers(body: NimNode): seq[NimNode] =
  var
    collected: seq[NimNode]
    active: seq[NimNode]

  proc visit(node: NimNode)

  proc visitHelper(symbol: NimNode) =
    if symbol.kind != nnkSym:
      return

    if symbol.symKind notin {nskProc, nskFunc}:
      return

    if symbol.intrinsicName.len > 0:
      return

    if symbol in collected:
      return

    if symbol in active:
      error "recursive shader helpers are not supported", symbol

    let impl = symbol.getImpl

    if impl.kind notin {nnkProcDef, nnkFuncDef}:
      return

    if impl[2].len > 0 or impl.params.containsGenericParameter:
      error(
        "cannot emit shader helper '" & symbol.strVal & "': " &
        "its implementation still contains generic parameters.\n",
        symbol
      )

    for pragma in impl.pragma:
      let name =
        if pragma.kind == nnkExprColonExpr: pragma[0]
        else: pragma

      if name.eqIdent("magic") or name.eqIdent("importc"):
        return

    if impl.body.kind == nnkEmpty:
      return

    active.add symbol
    visit impl.body
    active.setLen(active.len - 1)

    collected.add symbol

  proc visit(node: NimNode) =
    if node.kind in {nnkProcDef, nnkFuncDef, nnkLambda}:
      return

    if node.kind in {nnkCall, nnkCommand}:
      visitHelper node[0]

    for child in node:
      visit child

  visit body

  collected

proc identifiers(node: NimNode): seq[string] =
  if node.kind in {nnkIdent, nnkSym}:
    result.add node.strVal

  for child in node:
    result.add child.identifiers

proc emitBody(
  body: NimNode,
  isShaderMain = false,
  hasResult = false
): string =
  var
    usedNames = body.identifiers
    temporaryIndex = 0

  proc emitExpr(
    node: NimNode,
    parentPrecedence = 0,
    isRightOperand = false
  ): string =
    case node.kind
    of nnkIdent:
      result = node.strVal

    of nnkSym:
      if node == bindSym"Identity3":
        result = "mat3(1.0)"

      elif node == bindSym"Identity4":
        result = "mat4(1.0)"

      elif node.symKind == nskConst:
        let
          impl = node.getImpl
          value =
            if impl.kind == nnkConstDef: impl[^1]
            else: impl

        return value.emitExpr(
          parentPrecedence,
          isRightOperand
        )

      else:
        let name = node.intrinsicName

        result =
          if name.len > 0: name
          else: node.strVal

    of nnkDotExpr:
      let field = node[1].strVal

      if isShaderMain and node[0].eqIdent("result"):
        result =
          if field == "pos": "gl_Position"
          else: field

      elif isShaderMain and
        sameType(node[0].getTypeImpl, bindSym"Vertex"):
        result = "vert" & field.capitalizeAscii

      else:
        result = node[0].emitExpr(7) & "." & field

    of nnkCall, nnkCommand:
      let
        callee = node[0]
        intrinsic = callee.intrinsicName

      case intrinsic
      of ".xy", ".xyz":
        if node.len != 2:
          error "swizzle expects one argument", node

        result = node[1].emitExpr(7) & intrinsic

      of "textureSize":
        if node.len != 2:
          error "texture size expects one argument", node

        result = "vec2(textureSize(" & node[1].emitExpr & ", 0))"

      else:
        let args = node.toSeq[1..^1]
          .mapIt(it.emitExpr)
          .join(", ")

        result = callee.emitExpr & "(" & args & ")"

    of nnkStmtListExpr:
      for index in 0 ..< node.len - 1:
        if node[index].kind notin {nnkEmpty, nnkProcDef, nnkFuncDef}:
          error "statements inside expressions are not supported yet", node

      return node[^1].emitExpr(
        parentPrecedence,
        isRightOperand
      )

    of nnkBracketExpr:
      result = node[0].emitExpr(7) & "[" & node[1].emitExpr & "]"

    of nnkBracket:
      result = node.getTypeInst.glslType & "(" &
        node.toSeq.mapIt(it.emitExpr).join(", ") & ")"

    of nnkInfix:
      let operator = node[0].glslOperator

      result = node[1].emitExpr(node.precedence) &
        " " & operator & " " &
        node[2].emitExpr(node.precedence, true)

    of nnkPrefix:
      result = node[0].glslOperator &
        node[1].emitExpr(node.precedence, true)

    of nnkIfExpr:
      result = "("

      for branch in node:
        case branch.kind
        of nnkElifExpr, nnkElifBranch:
          result.add branch[0].emitExpr & " ? " &
            branch[1].emitExpr & " : "

        of nnkElseExpr, nnkElse:
          result.add branch[0].emitExpr

        else:
          error "unsupported shader conditional branch", branch

      result.add ")"

    of nnkHiddenStdConv, nnkHiddenSubConv,
      nnkHiddenAddr, nnkHiddenDeref:
      return node[^1].emitExpr(
        parentPrecedence,
        isRightOperand
      )

    of nnkConv:
      result = node[0].glslType & "(" & node[1].emitExpr & ")"

    of nnkFloatLit..nnkFloat64Lit:
      result = $node.floatVal

    of nnkIntLit..nnkUInt64Lit:
      result = $node.intVal

    else:
      error "unsupported shader expression: " & $node.kind, node

    if node.precedence < parentPrecedence or
       (node.precedence == parentPrecedence and isRightOperand):
      result = "(" & result & ")"

  proc freshName(): string =
    while true:
      result = "keaTemp" & $temporaryIndex
      inc temporaryIndex

      if result notin usedNames:
        usedNames.add result
        return

  proc needsStatements(node: NimNode): bool =
    case node.kind
    of nnkStmtListExpr:
      for index in 0 ..< node.len - 1:
        if node[index].kind notin {nnkEmpty, nnkProcDef, nnkFuncDef}:
          return true

      result = node[^1].needsStatements

    of nnkIfExpr:
      for branch in node:
        for child in branch:
          if child.needsStatements:
            return true

    of nnkHiddenStdConv, nnkHiddenSubConv,
       nnkHiddenAddr, nnkHiddenDeref:
      result = node[^1].needsStatements

    else:
      result = false

  proc emitStmt(node: NimNode): string

  proc emitInto(target: string, value: NimNode): string =
    case value.kind
    of nnkIfExpr:
      for index, branch in value:
        if index > 0:
          result.add " else "

        case branch.kind
        of nnkElifExpr, nnkElifBranch:
          result.add "if (" & branch[0].emitExpr & ") "

        of nnkElseExpr, nnkElse:
          discard

        else:
          error "unsupported shader conditional branch", branch

        result.add "{\n"
        result.add emitInto(target, branch[^1])
        result.add "}"

      result.add "\n"

    of nnkStmtListExpr:
      result.add "{\n"

      for index in 0 ..< value.len - 1:
        result.add value[index].emitStmt

      result.add emitInto(target, value[^1])
      result.add "}\n"

    of nnkHiddenStdConv, nnkHiddenSubConv,
       nnkHiddenAddr, nnkHiddenDeref:
      result = emitInto(target, value[^1])

    else:
      result = target & " = " & value.emitExpr & ";\n"

  proc emitStmt(node: NimNode): string =
    case node.kind
    of nnkStmtList:
      for statement in node:
        result.add statement.emitStmt

    of nnkAsgn:
      let
        target = node[0]
        value = node[1]
        targetCode = target.emitExpr

      if value.needsStatements:
        result = emitInto(targetCode, value)
      else:
        result = targetCode & " = " & value.emitExpr & ";\n"

    of nnkLetSection, nnkVarSection:
      for definition in node:
        let value = definition[^1]

        for index in 0 ..< definition.len - 2:
          let
            symbol = definition[index]
            typ = symbol.getTypeInst
            name = symbol.strVal

          if typ.isTextureType:
            error "local texture declarations are not supported", symbol

          if value.needsStatements:
            let temporary = freshName()

            result.add typ.glslType & " " & temporary & ";\n"
            result.add emitInto(temporary, value)
            result.add typ.glslType & " " & name &
              " = " & temporary & ";\n"

          else:
            let initializer =
              if value.kind == nnkEmpty: ""
              else: " = " & value.emitExpr

            result.add typ.glslType & " " & name &
              initializer & ";\n"

    of nnkInfix, nnkCall, nnkCommand:
      result = node.emitExpr & ";\n"

    of nnkIfStmt:
      for index, branch in node:
        if index > 0:
          result.add " else "

        if branch.kind == nnkElifBranch:
          result.add "if (" & branch[0].emitExpr & ") "

        result.add "{\n" & branch[^1].emitStmt & "}"

      result.add "\n"

    of nnkForStmt:
      if node.len != 3:
        error "unsupported shader loop", node

      let
        variable = node[0]
        interval = node[1]
        name = variable.strVal

      if interval.kind notin {nnkInfix, nnkCall} or interval.len != 3:
        error "unsupported shader loop iterator", interval

      let
        start = interval[1].emitExpr
        finish = interval[2].emitExpr
        comparison =
          case interval[0].strVal
          of "..<": "<"
          of "..": "<="
          else:
            error "unsupported shader loop iterator", interval

      result = "for (" & variable.getTypeInst.glslType & " " &
        name & " = " & start & "; " & name & " " &
        comparison & " " & finish & "; ++" &
        name & ") {\n" & node[^1].emitStmt & "}\n"

    of nnkReturnStmt:
      let value = node[0]

      if value.kind == nnkAsgn:
        result.add value.emitStmt

      elif value.kind != nnkEmpty:
        if value.needsStatements:
          let temporary = freshName()

          result.add value.getTypeInst.glslType &
            " " & temporary & ";\n"

          result.add emitInto(temporary, value)
          result.add "return " & temporary & ";\n"
          return

        return "return " & value.emitExpr & ";\n"

      result.add(
        if hasResult and not isShaderMain: "return result;\n"
        else: "return;\n"
      )

    of nnkDiscardStmt:
      if node[0].kind != nnkEmpty:
        result.add node[0].emitExpr

      result.add ";\n"

    of nnkEmpty, nnkProcDef, nnkFuncDef:
      discard

    else:
      error "unsupported shader statement: " & $node.kind, node

  body.emitStmt

proc emitHelper(helper: NimNode): string =
  proc zeroValue(typ: NimNode): string =
    let name = typ.glslType
    var values = @["0"]

    if typ.glslBuiltinType.len == 0:
      let impl = typ.getTypeImpl

      if impl.kind == nnkBracketExpr and impl[0].eqIdent("array"):
        values = newSeqWith(impl.arrayLength, impl[^1].zeroValue)

      elif impl.kind == nnkObjectTy:
        values = impl[^1].fields.toSeq.mapIt(it.typ.zeroValue)

    name & "(" & values.join(", ") & ")"

  let
    signature = helper.signature

    body = helper.implementation.body

    hasResult = signature.returnType.kind != nnkEmpty

    parameters = signature.parameters.mapIt(
      it.typ.glslType & " " & it.name.strVal
    ).join(", ")

    returnType =
      if hasResult: signature.returnType.glslType
      else: "void"

  result =
    returnType & " " & helper.strVal &
    "(" & parameters & ") {\n"

  if hasResult and signature.returnType.isTextureType:
    error "shader helpers cannot return textures", helper

  if hasResult:
    result.add returnType & " result = " &
      signature.returnType.zeroValue & ";\n"

  result.add body.emitBody(hasResult = hasResult)

  if hasResult:
    result.add "return result;\n"

  result.add "}\n"

proc emitMain(body: NimNode): string =
  "\nvoid main() {\n" &
  body.emitBody(isShaderMain = true) &
  "}"

proc validateOutputType(typ: NimNode) =
  for allowed in [
    bindSym"float32",
    bindSym"int32",
    bindSym"Vec2",
    bindSym"Vec3",
    bindSym"Vec4"
  ]:
    if sameType(typ, allowed):
      return

  error "unsupported shader output type: " & typ.repr, typ

proc vertGlslImpl*(shader: NimNode): string =
  let signature = shader.signature

  if signature.returnType.kind != nnkTupleTy:
    error "vertex shader must return a tuple", shader

  let posType = signature.returnType.fieldType(ident"pos")

  if posType.isNil:
    error "vertex shader must have pos output", shader

  if not sameType(posType, bindSym"Vec4"):
    error "vertex shader pos output must be vec4", shader

  let
    body = shader.implementation.body
    helpers = body.helpers

  result.add VertexHeader.dedent
  result.add emitUsedStructs(shader, helpers)

  for field in signature.returnType.fields:
    let typ = field.typ

    if not sameType(typ, bindSym"Mat3") and
       not sameType(typ, bindSym"Mat4"):
      validateOutputType(typ)

    if field.name.strVal == "pos":
      continue

    let qualifier =
      if sameType(typ, bindSym"int32"): "flat out "
      else: "out "

    result.add qualifier & declaration(typ, field.name.strVal)

  for param in signature.parameters:
    if sameType(param.typ, bindSym"Vertex"):
      continue

    if param.name.strVal in ["model", "nmat"]:
      continue

    result.add "uniform " & declaration(param.typ, param.name.strVal)

  result.add "\n" & helpers
    .mapIt(it.emitHelper)
    .join("\n")

  result.add body.emitMain

proc fragGlslImpl*(vert, frag: NimNode): string =
  let
    signature = frag.signature
    returnType = signature.returnType
    vertSignature = vert.signature

  if returnType.kind != nnkTupleTy:
    error "fragment shader must return a tuple", frag

  if returnType.containsField(ident"pos"):
    error "'pos' is reserved for vertex shader outputs", frag

  let
    body = frag.implementation.body
    helpers = body.helpers

  result.add FragmentHeader.dedent
  result.add emitUsedStructs(frag, helpers)

  for location, field in returnType.fields.toSeq:
    validateOutputType(field.typ)

    result.add(
      "layout (location = " & $location & ") out " &
      declaration(field.typ, field.name.strVal)
    )

  for param in signature.parameters:
    let
      name = param.name.strVal
      varyingType = vertSignature.returnType.fieldType(param.name)
      isVarying = name != "pos" and not varyingType.isNil

    if isVarying and varyingType.isTextureType:
      error "texture '" & name & "' cannot be a varying", param.name

    if isVarying and not sameType(param.typ, varyingType):
      error(
        "fragment input '" & name &
        "' has type " & param.typ.repr &
        ", but vertex output has type " & varyingType.repr,
        param.name
      )

    if not isVarying:
      for vertParam in vertSignature.parameters:
        if vertParam.name.strVal == name and
           not sameType(param.typ, vertParam.typ):
          error "conflicting uniform types for '" & name & "'", param.name

    let qualifier =
      if not isVarying: "uniform "
      elif sameType(param.typ, bindSym"int32"): "flat in "
      else: "in "

    result.add qualifier & declaration(param.typ, name)

  result.add "\n" & helpers
    .mapIt(it.emitHelper)
    .join("\n")

  result.add body.emitMain

macro vertGlsl*(shader: typed): string =
  newStrLitNode vertGlslImpl(shader)

macro fragGlsl*(vert, frag: typed): string =
  newStrLitNode fragGlslImpl(vert, frag)

func materialType*(
  vert, frag: NimNode,
  globals: NimNode
): NimNode =
  let
    vertSignature = vert.signature
    fragSignature = frag.signature
    globalsType = globals.getTypeImpl

  result = newNimNode(nnkTupleTy)

  for param in vertSignature.parameters & fragSignature.parameters:
    if sameType(param.typ, bindSym"Vertex"):
      continue

    if param.name.strVal in ["model", "nmat"]:
      continue

    if globalsType.containsField(param.name) or
       vertSignature.returnType.containsField(param.name) or
       result.containsField(param.name):
      continue

    result.add newIdentDefs(
      param.name.strVal.ident,
      param.typ.copyNimTree
    )

func attachmentsType*(frag: NimNode): NimNode =
  frag.signature.returnType.copyNimTree
