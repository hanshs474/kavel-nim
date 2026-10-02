## kavel "an isometric coffee shop, pastel palette"
import std/[os, strutils]
import ../kavel

let prompt = commandLineParams().join(" ")
if prompt.len == 0:
  stderr.writeLine "usage: kavel \"your prompt\""
  quit 2
let r = generate(prompt)
if r.ok:
  echo r.image.url
else:
  stderr.writeLine $r.reason & ": " & r.message
  quit 1
