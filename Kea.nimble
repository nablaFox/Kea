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

task ltc, "Regenerate LTC lookup tables":
  exec "nim r -d:release --path:src tools/ltc_fitter.nim"
