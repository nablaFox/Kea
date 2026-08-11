# Package

version       = "0.1.0"
author        = "nablaFox"
description   = "Real-time rendering library"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["Kea"]

# Dependencies

requires "nim >= 2.2.10"
requires "nimgl >= 1.3.2"

# Tasks

task ggx_fit, "Regenerate LTC lookup tables for isotropic ggx distribution":
  exec "nim r -d:release --path:src tools/ggx_fitter.nim"
