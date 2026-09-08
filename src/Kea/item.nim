import mesh, transform, math

type
  Renderable* = ref object
    mesh*: Mesh
    topology*: Topology
    transform*: Transform

  RenderItem*[M: tuple] = ref object
    renderable*: Renderable
    material*: M

proc new*[M](
  mesh: Mesh,
  transform: Transform,
  material: M = (),
  topology: Topology = Triangles,
): RenderItem[M] =
  RenderItem[M](
    renderable: Renderable(
      mesh: mesh,
      topology: topology,
      transform: transform,
    ),
    material: material,
  )

proc new*[M](
  mesh: Mesh,
  material: M = (),
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0),
  topology: Topology = Triangles
): RenderItem[M] =
  new(
    mesh,
    transform.new(
      x = x,
      y = y,
      z = z,
      yaw = yaw,
      pitch = pitch,
      roll = roll,
      scale = scale,
    ),
    material,
    topology,
  )

proc transform*(renderable: Renderable): var Transform =
  renderable.transform

proc position*(renderable: Renderable): var Vec3 =
  renderable.transform.position

proc positioned*(renderable: Renderable): Vec3 =
  let transform = renderable.transform
  transform.position

proc scale*(renderable: Renderable): var Vec3 =
  renderable.transform.scale

proc scaled*(renderable: Renderable): Vec3 =
  let transform = renderable.transform
  transform.scale

proc rotation*(renderable: Renderable): var Mat3 =
  renderable.transform.rotation

proc rotated*(renderable: Renderable): Mat3 =
  let transform = renderable.transform
  transform.rotation

proc model*(renderable: Renderable): Mat4 =
  renderable.transform.model

proc transform*(item: RenderItem): var Transform =
  item.renderable.transform

proc position*(item: RenderItem): var Vec3 =
  item.renderable.transform.position

proc positioned*(item: RenderItem): Vec3 =
  item.renderable.positioned

proc scale*(item: RenderItem): var Vec3 =
  item.renderable.scale

proc scaled*(item: RenderItem): Vec3 =
  item.renderable.scaled

proc rotation*(item: RenderItem): var Mat3 =
  item.renderable.rotation

proc rotated*(item: RenderItem): Mat3 =
  item.renderable.rotated

proc model*(item: RenderItem): Mat4 =
  item.renderable.model
