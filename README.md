# Kea Renderer

Physically based renderer to display realtime physics simulations in a neutral
and professional studio.

## Features

- BDRF with Cook-Torrance specular and lambertian diffuse (ok)
- HDR (ok)
- Gamma correction (ok)
- Area light (ok)
- Dynamic shadows
- Multiple scattering energy compensation
- Diffuse IBL
- Specular IBL
- GTAO
- Lagarde specular AO
- Single dielectric transmission
- Stacked dielectric transmission
- SSS

## References

Cook-torrance bdrf:

- https://www.graphics.cornell.edu/~bjw/microfacetbsdf.pdf
- https://cseweb.ucsd.edu/~viscomp/classes/cse168/sp26/readings/cookpaper.pdf
- https://learnopengl.com/PBR/Lighting
- https://pbr-book.org/4ed/Radiometry,_Spectra,_and_Color/Radiometry

Area Light:

- https://eheitzresearch.wordpress.com/415-2/
- https://learnopengl.com/Guest-Articles/2022/Area-Lights
- https://hal.science/hal-01458129v1/document
- https://cdn.iiit.ac.in/cdn/cvit.iiit.ac.in/images/ConferencePapers/2022/Bringing_ggx.pdf
- https://advances.realtimerendering.com/s2016/s2016_ltc_fresnel.pdf
- https://advances.realtimerendering.com/s2016/s2016_ltc_rnd.pdf

Dynamic shadows:

- https://research.nvidia.com/sites/default/files/pubs/2018-05_Combining-Analytic-Direct//I3D2018_combining.pdf

Others:

- https://blog.selfshadow.com/publications/s2017-shading-course/imageworks/s2017_pbs_imageworks_slides_v2.pdf
- https://eheitzresearch.wordpress.com/240-2/
- https://blog.selfshadow.com/publications/turquin/ms_comp_final.pdf
- https://jcgt.org/published/0008/01/03/
- http://www.lighthouse3d.com/tutorials/glsl-tutorial/the-normal-matrix/
- https://google.github.io/filament/main/filament.html#improving-the-brdfs
