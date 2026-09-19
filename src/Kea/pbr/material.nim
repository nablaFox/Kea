import Kea/colors

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
