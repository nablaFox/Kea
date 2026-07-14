import core
import mesh
import material
import transform

type
  Drawable* = object
    state: ref KeaState
    id: HandleId

proc add*(
  kea: Kea,
  mesh: Mesh,
  transform = IdentityTransform,
  material = DefaultMaterial
): Drawable =
  discard

proc add*(
  kea: Kea,
  primitive: Primitive,
  transform = IdentityTransform,
  material = DefaultMaterial
): Drawable =
  let mesh = kea.createMesh(primitive)
  result = kea.add(mesh, transform, material)
