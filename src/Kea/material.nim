import colors

type
  Material* = object
    albedo*: Color
    roughness*: float32
    metallic*: float32

const Default* = Material(
  albedo: White,
  roughness: 0.5,
  metallic: 0.0
)

const Red* = Material(
  albedo: [1.0, 0.0, 0.0, 1.0],
  roughness: 0.5,
  metallic: 0.0
)
