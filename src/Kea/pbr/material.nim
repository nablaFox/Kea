import
  Kea/colors,
  std/macros

const
  Red* = (
    albedo: [1.0'f, 0.0, 0.0],
    roughness: 0.5'f,
    metallic: 0.0'f
  )

  White* = (
    albedo: [1.0'f, 1.0, 1.0],
    roughness: 0.5'f,
    metallic: 0.0'f
  )

proc new*(
  albedo: Color = [1.0, 1.0, 1.0],
  roughness: float32 = 0.5,
  metallic: float32 = 0.0
): auto =
  (
    albedo: albedo,
    roughness: roughness,
    metallic: metallic
  )

macro new*(args: varargs[untyped]): untyped =
  let
    base = genSym(nskLet, "material")
    baseCall = newCall(bindSym"new")
    fields = newNimNode(nnkTupleConstr)

  for name in ["albedo", "roughness", "metallic"]:
    fields.add newTree(
      nnkExprColonExpr,
      ident(name),
      newDotExpr(base, ident(name))
    )

  for arg in args:
    if arg.kind != nnkExprEqExpr or
        arg[0].eqIdent("albedo") or
        arg[0].eqIdent("roughness") or
        arg[0].eqIdent("metallic"):
      baseCall.add arg
      continue

    fields.add newTree(nnkExprColonExpr, arg[0], arg[1])

  result = quote do:
    block:
      let `base` = `baseCall`
      `fields`
