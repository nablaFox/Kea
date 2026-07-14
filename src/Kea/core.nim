import keys

type
  HandleId* = object
    index*: uint32
    generation*: uint32

  MeshData* = object

  DrawableData* = object

  KeaState* = object
    width*: Natural
    height*: Natural
    title*: string

    meshes*: seq[MeshData]
    drawables*: seq[DrawableData]

    currentKeys*: array[Key, bool]
    previousKeys*: array[Key, bool]

  Kea* = object
    state*: ref KeaState

proc `=copy`*(dest: var Kea; source: Kea) {.error.}

proc `=destroy`*(kea: var Kea) =
  echo "kea destroyed"

proc initKea*(width: Natural, height: Natural, title: string): Kea =
  new(result.state)

  result.state[] = KeaState(
    width: width,
    height: height,
    title: title,
    meshes: @[],
    drawables: @[]
  )
