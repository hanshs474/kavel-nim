## Kavel — generate an AI image from Nim.
##
## Kavel is a free AI video generator and AI image generator at https://www.kavel.ai.
## Without an API key a call runs on Kavel's free allowance (text to image).
## With a key (``apiKey`` or the ``KAVEL_API_KEY`` environment variable) it runs on
## your Kavel account: your credits and the image models your plan includes.
##
## .. code-block:: nim
##   import kavel
##   echo generate("a paper-cut fox in a moonlit forest")
##
## Compile with ``-d:ssl``.

import std/[httpclient, json, os, random, strutils, times, uri]

const
  BaseUrl* = "https://www.kavel.ai"
  KeysUrl* = BaseUrl & "/settings/apikeys"
  FreeModel = "kavel-image-v1"
  UserAgent = "kavel-nim/0.1.0"

type KavelError* = object of CatchableError
  ## Raised with a readable reason: spent allowance, refused prompt, bad key, timeout.

proc anonId(): string =
  randomize()
  result = "nim-"
  for _ in 0 ..< 16: result.add "0123456789abcdef"[rand(15)]

proc call(c: HttpClient, meth: HttpMethod, url: string, body: JsonNode): JsonNode =
  let resp = c.request(url, httpMethod = meth,
                       body = (if body.isNil: "" else: $body))
  try:
    result = parseJson(resp.body)
  except JsonParsingError:
    result = %*{"code": -1, "message": "HTTP " & resp.status}

proc generate*(prompt: string, apiKey = "", model = "", aspectRatio = "1:1",
               timeoutSec = 360, pollEverySec = 5): string =
  ## Generates one image and returns its URL.
  let text = prompt.strip
  if text.len == 0: raise newException(KavelError, "write a prompt first")
  let key = if apiKey.len > 0: apiKey else: getEnv("KAVEL_API_KEY")
  var headers = newHttpHeaders({"Content-Type": "application/json", "User-Agent": UserAgent})
  if key.len > 0: headers["Authorization"] = "Bearer " & key
  else: headers["x-anon-id"] = anonId()
  let c = newHttpClient(headers = headers, timeout = 60_000)
  defer: c.close()

  let submit = c.call(HttpPost, BaseUrl & "/api/ai/generate", %*{
    "provider": "kie", "mediaType": "image",
    "model": (if key.len > 0 and model.len > 0: model else: FreeModel),
    "scene": "text-to-image", "prompt": text,
    "options": {"aspect_ratio": aspectRatio}})
  if submit{"code"}.getInt(-1) != 0:
    raise newException(KavelError, submit{"message"}.getStr("request refused"))
  let data = submit{"data"}
  if data{"wall"}.getBool(false):
    raise newException(KavelError, "the free allowance is spent - pass an API key from " & KeysUrl)
  let task = data{"id"}.getStr
  if task.len == 0: raise newException(KavelError, "Kavel returned no task id")

  let deadline = epochTime() + timeoutSec.float
  while epochTime() < deadline:
    sleep(pollEverySec * 1000)
    var env: JsonNode
    try:
      env = if key.len > 0:
        c.call(HttpPost, BaseUrl & "/api/ai/query", %*{"taskId": task})
      else:
        c.call(HttpGet, BaseUrl & "/api/ai/anon-query?" & encodeQuery(
          {"taskId": task, "provider": "kie", "mediaType": "image"}), nil)
    except CatchableError:
      continue # a dropped poll is not a failed generation
    if env{"code"}.getInt(-1) != 0: continue
    let d = env{"data"}
    if d{"status"}.getStr == "failed":
      raise newException(KavelError, "generation failed - try another prompt")
    for field in ["cleanImages", "images"]:
      let imgs = d{field}
      if not imgs.isNil and imgs.kind == JArray and imgs.len > 0:
        let first = imgs[0]
        return (if first.kind == JObject: first{"url"}.getStr else: first.getStr)
  raise newException(KavelError, "still running after " & $timeoutSec & " seconds (task " & task & ")")

when isMainModule:
  let prompt = commandLineParams().join(" ")
  if prompt.len == 0:
    quit("usage: kavel <prompt>", 2)
  try:
    echo generate(prompt)
  except KavelError as e:
    quit("kavel: " & e.msg, 1)
