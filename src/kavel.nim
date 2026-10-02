## Generate and edit AI images from Nim with no API key and no account.
##
## .. code-block:: nim
##   import kavel
##   let r = generate("matte black ceramic mug on pale oak, soft window light")
##   if r.ok: echo r.image.url else: echo r.reason, ": ", r.message
##
## Without a key this calls the anonymous tier of https://www.kavel.ai, which
## meters a small free allowance against a client id this module invents
## rather than an account you register. Pass `apiKey` (or set KAVEL_API_KEY)
## to run on your account.
##
## Compile with `-d:ssl`.

import std/[httpclient, json, os, random, strutils, times, uri]

type
  Reason* = enum
    rNone = "none"
    rQuota = "quota"        ## free allowance spent; wait, or pass a key
    rRejected = "rejected"  ## prompt refused; reword it
    rSignIn = "sign_in"     ## needs an account
    rAuth = "auth"          ## invalid API key
    rTimeout = "timeout"    ## no image before the deadline
    rOther = "other"

  Image* = object
    url*: string          ## permanent, cacheable CDN link
    watermarked*: bool    ## whether a mark was actually drawn

  Result* = object
    ok*: bool
    image*: Image
    reason*: Reason
    message*: string

  Options* = object
    aspectRatio*: string  ## "1:1", "16:9", "9:16", "4:3" or "3:4"
    apiKey*: string       ## key from https://www.kavel.ai/settings/apikeys
    model*: string        ## engine override, honoured only with a key
    pollSeconds*: int
    timeoutSeconds*: int

var baseUrl* = "https://www.kavel.ai"

proc defaultOptions*(): Options =
  Options(aspectRatio: "1:1", pollSeconds: 5, timeoutSeconds: 360)

proc fail(r: Reason, msg: string): Result =
  Result(ok: false, reason: r, message: "kavel: " & msg)

proc anonId(): string =
  randomize()
  result = "nim-"
  for _ in 1..8: result.add toHex(rand(255), 2).toLowerAscii

proc keyOf(o: Options): string =
  if o.apiKey.len > 0: o.apiKey else: getEnv("KAVEL_API_KEY")

# Refusals answer HTTP 200 with code -1 and a human message.
proc request(c: HttpClient, meth: HttpMethod, url: string, body = ""): (bool, JsonNode, Result) =
  var resp: Response
  try:
    resp = c.request(url, httpMethod = meth, body = body)
  except CatchableError as e:
    return (false, nil, fail(rOther, e.msg))
  var env: JsonNode
  try:
    env = parseJson(resp.body)
  except CatchableError:
    return (false, nil, fail(rOther, "unexpected response"))
  if env{"code"}.getInt(-1) != 0:
    let msg = env{"message"}.getStr("request refused")
    let low = msg.toLowerAscii
    let r =
      if "invalid api key" in low: rAuth
      elif "insufficient credits" in low: rQuota
      elif "sign in" in low or "subscription" in low: rSignIn
      else: rOther
    return (false, nil, fail(r, msg))
  (true, (if env.hasKey("data"): env["data"] else: newJObject()), Result())

proc run(payload: JsonNode, o: Options): Result =
  let key = keyOf(o)
  let c = newHttpClient(timeout = 60_000)
  defer: c.close()
  c.headers = newHttpHeaders({"Content-Type": "application/json"})
  if key.len > 0: c.headers["Authorization"] = "Bearer " & key
  else: c.headers["x-anon-id"] = anonId()
  let deadline = epochTime() + float(if o.timeoutSeconds > 0: o.timeoutSeconds else: 360)

  let (ok, d, err) = request(c, HttpPost, baseUrl & "/api/ai/generate", $payload)
  if not ok: return err
  # The quota wall answers 200 with code 0 and wall: true.
  if d{"wall"}.getBool(false):
    case d{"reason"}.getStr("")
    of "anon_ip_daily": return fail(rQuota, "this machine has used its free credits for today")
    of "anon_unmetered_video": return fail(rSignIn, "this needs a signed-in account")
    else: return fail(rQuota, "the free allowance does not cover this run")
  let task = d{"id"}.getStr("")
  if task.len == 0: return fail(rOther, "the service returned no task id")

  while epochTime() < deadline:
    sleep(1000 * (if o.pollSeconds > 0: o.pollSeconds else: 5))
    let (pok, p, _) =
      if key.len > 0: request(c, HttpPost, baseUrl & "/api/ai/query", $(%*{"taskId": task}))
      else: request(c, HttpGet, baseUrl & "/api/ai/anon-query?taskId=" & encodeUrl(task) & "&provider=kie&mediaType=image")
    # Free runs only start when a poll crosses the end of the queue, so a
    # dropped poll is not a failed job: keep going.
    if not pok: continue
    if p{"cleanImages"}.len > 0:
      return Result(ok: true, image: Image(url: p["cleanImages"][0].getStr, watermarked: false))
    if p{"images"}.len > 0:
      let wm = p{"watermarked"}.len > 0 and p["watermarked"][0].getBool(false)
      return Result(ok: true, image: Image(url: p["images"][0].getStr, watermarked: wm))
    if p{"status"}.getStr("") in ["failed", "error"]:
      return fail(rRejected, "prompt refused; reword it")
  fail(rTimeout, "no image before the deadline")

proc generate*(prompt: string, o = defaultOptions()): Result =
  ## Turns a prompt into a new image. Naming the light, the material and the
  ## composition moves the result far more than adding adjectives.
  if prompt.strip.len == 0: return fail(rOther, "prompt is required")
  let model = if keyOf(o).len > 0 and o.model.len > 0: o.model else: "kavel-image-v1"
  run(%*{"provider": "kie", "mediaType": "image", "model": model, "scene": "text-to-image",
         "prompt": prompt, "options": {"aspect_ratio": (if o.aspectRatio.len > 0: o.aspectRatio else: "1:1")}}, o)

proc edit*(sourceUrl, instruction: string, o = defaultOptions()): Result =
  ## Rewrites the image at a public url. An edit costs more than the free
  ## allowance, so without a key this returns `rQuota` before anything is charged.
  if not (sourceUrl.startsWith("http://") or sourceUrl.startsWith("https://")):
    return fail(rOther, "sourceUrl must be a public http(s) url")
  if instruction.strip.len == 0: return fail(rOther, "instruction is required")
  let model = if keyOf(o).len > 0 and o.model.len > 0: o.model else: "nano-banana-2-lite"
  run(%*{"provider": "kie", "mediaType": "image", "model": model, "scene": "image-to-image",
         "prompt": instruction, "options": {"image_input": [sourceUrl]}}, o)

proc credits*(): tuple[ok: bool, remaining, grant: int, message: string] =
  ## What a fresh anonymous client id is granted. Free to call.
  let c = newHttpClient(timeout = 30_000)
  defer: c.close()
  c.headers = newHttpHeaders({"x-anon-id": anonId()})
  let (ok, d, err) = request(c, HttpGet, baseUrl & "/api/ai/anon-credits")
  if not ok: return (false, 0, 0, err.message)
  (true, d{"remaining"}.getInt, d{"grant"}.getInt, "")
