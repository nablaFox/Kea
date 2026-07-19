# Kea Renderer

Physically based renderer to display realtime physics simulations in a neutral
and professional studio.

## Features

- BDRF with Cook-Torrance specular and lambertian diffuse (ok)
- HDR (ok)
- Gamma correction (ok)
- Area light & dynamic shadows
- Planar reflections
- Anisotropic BDRF
- Multiple scattering energy compensation
- Diffuse IBL
- Specular IBL
- GTAO
- Lagarde specular AO
- horizon specular occlusion

## References

Cook-torrance bdrf:

- https://www.graphics.cornell.edu/~bjw/microfacetbsdf.pdf
- https://cseweb.ucsd.edu/~viscomp/classes/cse168/sp26/readings/cookpaper.pdf
- https://learnopengl.com/PBR/Lighting
- https://pbr-book.org/4ed/Radiometry,_Spectra,_and_Color/Radiometry

Area Light & dynamic shadows:

- https://learnopengl.com/Guest-Articles/2022/Area-Lights
- https://eheitzresearch.wordpress.com/415-2/
- https://hal.science/hal-01458129v1/document
- https://cdn.iiit.ac.in/cdn/cvit.iiit.ac.in/images/ConferencePapers/2022/Bringing_ggx.pdf
- https://research.nvidia.com/sites/default/files/pubs/2018-05_Combining-Analytic-Direct//I3D2018_combining.pdf
- https://advances.realtimerendering.com/s2016/s2016_ltc_fresnel.pdf

Others:

- https://blog.selfshadow.com/publications/s2017-shading-course/imageworks/s2017_pbs_imageworks_slides_v2.pdf
- http://www.lighthouse3d.com/tutorials/glsl-tutorial/the-normal-matrix/
