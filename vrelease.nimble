# Package

version       = "0.4.0"
author        = "Caian Ertl"
description   = "KISS solution to easily create project releases"
license       = "CC0-1.0"
srcDir        = "src"
bin           = @["vrelease"]


# Dependencies

requires "nim >= 1.6.0"
requires "docopt >= 0.7.1"
requires "nimSHA2 >= 0.1.1"
requires "semver >= 1.2.3"


task tests, "Run all tests":
  exec "nim c -r tests/main.nim"
