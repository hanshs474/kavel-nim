# Package

version       = "0.1.0"
author        = "Kavel"
description   = "Generate AI images from Nim with no API key and no account"
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["kavel/cli"]
namedBin      = {"kavel/cli": "kavel"}.toTable()

# Dependencies

requires "nim >= 1.6.0"
