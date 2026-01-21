import std/osproc
import std/sequtils
import std/strutils
import std/strformat
import std/sugar
import std/terminal


proc die* (msg: string, args: varargs[string, `$`]) =
  raise newException(Defect, format(msg, args))


proc execCmd* (cmd: string, panicOnError = true): (string, int) =
  let (output, exitCode) = execCmdEx(cmd)

  if panicOnError and exitCode > 0:
    let co = if len(output) > 0: format("; got:\n\n$1", output) else: ""
    let msg = fmt"command '{cmd}' failed with return code {exitCode}{co}"

    raise newException(Defect, msg)

  return (output, exitCode)


# no side-effects

func first* (t: seq[string]): string = t[0]


func last* (t: seq[string]): string = t[len(t) - 1]


func toColor (t: string, color: ForegroundColor, bright: bool): string =
  ansiForegroundColorCode(color, bright = bright) & t & ansiResetCode


func toBrightBlueColor* (t: string): string =
  t.toColor(fgBlue, true)


func toBrightCyanColor* (t: string): string =
  t.toColor(fgCyan, true)


func toBrightRedColor* (t: string): string =
  t.toColor(fgRed, true)


func toDimStyle* (t: string): string =
  ansiStyleCode(styleDim) & t & ansiResetCode


func toBoldStyle* (t: string): string =
  ansiStyleCode(styleBright) & t & ansiResetCode


func atRelativeIndex* (t: seq[string], i: int): string =
  if i >= 0:
    return t[i]

  # len + (- i)
  return t[len(t) + i]


proc mapC* [T, S](vals: seq[T], callback: (i: int, v: T) -> S): seq[S] =
  var r: seq[S] = @[]
  for i, val in vals:
    r.add(callback(i, val))

  return r


proc foreach* [T](vals: seq[T], fn: (v: T) -> void) =
  for _, val in vals:
    fn(val)


func splitClean* (text: string, v: string = "\n"): seq[string] =
  text
    .strip()
    .split(v)
    .mapIt(strip(it))
    .filterIt(len(it) > 0)


func limitTo* [T](vals: seq[T], v: int): seq[T] =
  if v < 0 or v >= len(vals):
    return vals

  if v == 0:
    return @[]

  return vals[0, len(vals) - v - 1]
