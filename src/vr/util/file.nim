import std/os
import std/strutils

import flow

import nimSHA2


type Attacheable* = object
  filepath* : string
  hash*     : string

proc resolveAssetPath* (p: string): string =
  let absPath = (
    if p.isAbsolute(): p
    else: p.absolutePath()
  )

  if fileExists(absPath):
    return absPath

  let r = p & (
    if p != absPath: format(" (resolved to '$1')", absPath)
    else: ""
  )

  die("asset path '$1' does not exists", r)

proc calculateSHA256ChecksumOf* (filepath: string): string =
   const blockSize = 8 * 1024
   var bytesRead: int = 0
   var buffer: string

   var f: File = open(filepath)
   var sha: SHA256
   sha.initSHA()

   buffer = newString(blockSize)
   bytesRead = f.readBuffer(buffer[0].addr, blockSize)
   setLen(buffer,bytesRead)

   while bytesRead > 0:
     sha.update(buffer)

     setLen(buffer,blockSize)
     bytesRead = f.readBuffer(buffer[0].addr, blockSize)
     setLen(buffer,bytesRead)

   return sha.final().hex().toLowerAscii()
