import
  core,
  texture,
  mesh,
  renderer,
  allocator,
  primitives,
  std/[tables, macros]

type
  CacheEntry[T] = ref object of RootObj
    value: T

  Resources* = ref object
    kea: Kea

    allocator: MeshAllocator
    
    meshes: Table[string, Mesh]
    textures: Table[string, RootRef]
    renderers: Table[string, RootRef]

proc new*(kea: Kea): Resources = 
  Resources(
    kea: kea,
    allocator: allocator.new(kea)
  )

template cached(
  cache: var Table[string, RootRef],
  key: string,
  create: untyped
): untyped =
  block:
    type T = typeof(create)

    let cacheKey = key
    let entry = cache.getOrDefault(cacheKey)
    var value: T

    if entry == nil:
      value = create
      cache[cacheKey] = CacheEntry[T](value: value)
    else:
      doAssert entry of CacheEntry[T],
        "Resource type mismatch: " & cacheKey

      value = CacheEntry[T](entry).value

    value
    
proc mesh*(
  res: Resources,
  primitive: Primitive,
  cached: bool = true
): Mesh = 
  if not cached:
    return res.allocator.mesh(primitive)

  let key = $primitive

  result = res.meshes.getOrDefault(key)

  if result == nil:
    result = res.allocator.mesh(primitive)
    res.meshes[key] = result

proc texture*(
  res: Resources,
  data: string,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions
): Texture[format] =
  texture.new(
    res.kea,
    data,
    width,
    height,
    format,
    options
  )

proc texture*(
  res: Resources,
  key: string,
  data: string,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions
): Texture[format] =
  const bytesPerPixel =
    case format
    of Rgba8Linear, Rgba8Srgb, R32Float, Depth24, Depth32Float: 4
    of Rg32Float: 8
    of Rgb32Float: 12
    of Rgba32Float: 16

  doAssert data.len > 0
  doAssert data.len == width * height * bytesPerPixel,
    "Texture data size does not match texture dimensions"

  result = cached(
    res.textures,
    key,
    texture.new(
      res.kea,
      nil,
      width,
      height,
      format,
      options
    )
  )

  doAssert result.width == width and result.height == height,
    "Cached texture dimensions do not match requested dimensions"

  result.update(addr data[0])

proc texture*(
  res: Resources,
  data: openArray[float32],
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): Texture[format] =
  texture.new(
    res.kea,
    data,
    width,
    height,
    format,
    options
  )

proc texture*(
  res: Resources,
  key: string,
  data: openArray[float32],
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): Texture[format] =
  result = cached(
    res.textures,
    key,
    texture.new(
      res.kea,
      nil,
      width,
      height,
      format,
      options
    )
  )

  doAssert result.width == width and result.height == height,
    "Cached texture dimensions do not match requested dimensions"

  result.update(data)

proc texture*(
  res: Resources,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): Texture[format] =
  texture.new(
    res.kea,
    nil,
    width,
    height,
    format,
    options
  )

proc texture*(
  res: Resources,
  key: string,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions,
): Texture[format] =
  cached(
    res.textures,
    key,
    texture.new(
      res.kea,
      nil,
      width,
      height,
      format,
      options
    )
  )

proc texture*(
  res: Resources,
  data: pointer,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions
): Texture[format] =
  texture.new(
    res.kea,
    data,
    width,
    height,
    format,
    options,
  )

proc texture*(
  res: Resources,
  key: string,
  data: pointer,
  width, height: Natural,
  format: static TextureFormat,
  options: TextureOptions
): Texture[format] =
  result = cached(
    res.textures,
    key,
    texture.new(
      res.kea,
      nil,
      width,
      height,
      format,
      options,
    )
  )

  doAssert result.width == width and result.height == height,
    "Cached texture dimensions do not match requested dimensions"

  if data != nil:
    result.update(data)

macro renderer*(
  res: Resources,
  vert, frag: typed,
  globals: typedesc[tuple] = tuple[]
): untyped =
  result = quote do:
    renderer.new(
      `res`.kea,
      `vert`,
      `frag`,
      `globals`,
    )

macro renderer*(
  res: Resources,
  key: string,
  vert, frag: typed,
  globals: typedesc[tuple] = tuple[]
): untyped =
  result = quote do:
    block:
      let r = cached(
        `res`.renderers,
        `key`,
        renderer.new(
          `res`.kea,
          `vert`,
          `frag`,
          `globals`,
        )
      )

      r
