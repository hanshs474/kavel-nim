# kavel

Generate AI images from Nim with **no API key and no account**.

```bash
nimble install kavel
kavel "an isometric coffee shop, pastel palette"
```

```nim
import kavel

let r = generate("matte black ceramic mug on pale oak, soft window light",
                 Options(aspectRatio: "16:9", pollSeconds: 5, timeoutSeconds: 360))
if r.ok:
  echo r.image.url          # https://cdn.kavel.ai/uploads/kie/image/....webp
  echo r.image.watermarked  # true on the free tier
else:
  echo r.reason, ": ", r.message
```

Compile with `-d:ssl`. Every other image client wants a key from OpenAI, fal or Replicate before it
runs once. This one calls the anonymous tier of
[Kavel](https://www.kavel.ai/?utm_source=nimble&utm_medium=package), an online AI image and video
studio, with a client id it invents instead of an account you register. Standard library only.

## Results you can branch on

`generate`, `edit` and `credits` never raise. `r.reason` is `rQuota` (wait, or pass a key),
`rRejected` (reword the prompt), `rSignIn`, `rAuth`, `rTimeout` or `rOther`.

## The free tier

`credits()` reads what a fresh client id is granted, and the call costs nothing. On 2026-10-02 the grant
was 5 credits, one generated image spent all five, and one IP got two images that day. Free output
is 1K and watermarked, and free runs queue before the model starts, so the default deadline is six
minutes.

## Editing a photo

```nim
var o = defaultOptions()
o.apiKey = getEnv("KAVEL_API_KEY")
let r = edit("https://example.com/portrait.jpg",
             "shoulder-length layered haircut, keep the same face, skin and lighting", o)
```

An edit costs more than the free grant, so it needs a key from
[kavel.ai/settings/apikeys](https://www.kavel.ai/settings/apikeys?utm_source=nimble&utm_medium=package).
Without one it returns `rQuota` before anything is charged.

## License

MIT. Generated with [Kavel AI](https://www.kavel.ai/?utm_source=nimble&utm_medium=package).
