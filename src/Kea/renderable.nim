import mesh, transform, math

type
  Renderable* = ref object
    mesh*: Mesh
    topology*: Topology
    transform*: Transform

proc new*(
  mesh: Mesh,
  transform: Transform,
  topology: Topology = Triangles
): Renderable =
  Renderable(
    mesh: mesh,
    topology: topology,
    transform: transform,
  )

proc new*(
  mesh: Mesh,
  x: float32 = 0.0,
  y: float32 = 0.0,
  z: float32 = 0.0,
  yaw: float32 = 0.0,
  pitch: float32 = 0.0,
  roll: float32 = 0.0,
  scale: Vec3 = vec3(1.0),
  topology: Topology = Triangles,
): Renderable =
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
    topology
  )

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
