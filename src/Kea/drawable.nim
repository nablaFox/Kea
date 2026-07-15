import mesh, transform, material, math

type
  Drawable* = ref object
    mesh*: Mesh
    transform*: Transform
    material*: Material

proc transform*(drawable: Drawable): var Transform =
  drawable.transform

proc position*(drawable: Drawable): var Vec3 =
  drawable.transform.position

proc positioned*(drawable: Drawable): Vec3 =
  let transform = drawable.transform
  transform.position

proc scale*(drawable: Drawable): var Vec3 =
  drawable.transform.scale

proc scaled*(drawable: Drawable): Vec3 =
  let transform = drawable.transform
  transform.scale

proc rotation*(drawable: Drawable): var Vec3 =
  drawable.transform.rotation

proc rotated*(drawable: Drawable): Vec3 =
  let transform = drawable.transform
  transform.rotation

proc model*(drawable: Drawable): Mat4 =
  drawable.transform.matrix
