## Kea Renderer

Physically based renderer to display realtime physics simulations in a neutral
and professional studio.

Features:

- BDRF with Cook-Torrance specular and lambertian diffuse
- HDR
- Gamma correction
- Area light
- Dynamic shadows
- Planar reflections
- Anisotropic BDRF
- Multiple scattering energy compensation
- Diffuse IBL
- Specular IBL
- GTAO
- Lagarde specular AO
- horizon specular occlusion

Resources:

- https://learnopengl.com
- https://www.graphics.cornell.edu/~bjw/microfacetbsdf.pdf
- https://cseweb.ucsd.edu/~viscomp/classes/cse168/sp26/readings/cookpaper.pdf
- https://pbr-book.org/4ed/contents
- https://google.github.io/filament/Filament.md.html
- https://blog.selfshadow.com/publications/s2017-shading-course/imageworks/s2017_pbs_imageworks_slides_v2.pdf

## Usage

```nim
import Kea

let kea = initKea(width=800, height=600, title="demo")

let ball = kea.createMesh(Sphere) # mesh is just an handle to internally saved mesh

let ball = kea.createMesh(vertices, indices) # with custom data

let drawable = kea.add(material, ball, transform) # optional transform

let drawable = kea.add(material, Sphere, transform) # optional transform

for frame in kea.frames:
    drawable.transform = transform

    kea.updateFirstPersonCamera(frame) # first person control
    kea.updateEditorCamera(frame) # editor control
    kea.camera.transform = transform # custom

    ball.updatePositions(positions) # mesh deformations

    if frame.input.keyPressed(Escape):
      break

    echo frame.delta

    kea.render()
```
