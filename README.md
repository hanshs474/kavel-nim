# kavel

Kavel is a free AI video generator and AI image generator — 4K clips with sound, and images you can run without an account or a card. This package calls it from Nim: one proc, standard library only.

```nim
import kavel

echo generate("a paper-cut fox in a moonlit forest")
# https://cdn.kavel.ai/uploads/…/….webp
```

Compile with `-d:ssl`. No key is needed for a first try: the call runs on Kavel's free allowance.

There is also a command-line tool:

```sh
nimble install kavel
kavel "a paper-cut fox in a moonlit forest"
```

## Past the free allowance

Create an API key on your Kavel account at https://www.kavel.ai/settings/apikeys and pass it (or set `KAVEL_API_KEY`):

```nim
echo generate("isometric tiny greenhouse", apiKey = getEnv("KAVEL_API_KEY"), model = "gpt-image-2")
```

With a key the call runs on your account: your credits, and the image models your [plan](https://www.kavel.ai/pricing?utm_source=nimble) includes. Every failure raises `KavelError` with a readable reason — spent allowance, refused prompt, wrong key or timeout.

## More from Kavel

Editing a photo instead of starting from a prompt? Kavel keeps a page per edit — [hairstyle](https://www.kavel.ai/image/ai-hairstyle-changer?utm_source=nimble), [outfit](https://www.kavel.ai/image/ai-outfit-generator?utm_source=nimble) and the rest under [AI image tools](https://www.kavel.ai/image?utm_source=nimble). Video lives under [AI video tools](https://www.kavel.ai/video?utm_source=nimble).

MIT licensed.
