import std/unittest
import kavel

suite "kavel":
  test "empty prompt is refused before any request":
    expect KavelError:
      discard generate("   ")
  test "constants point at kavel.ai":
    check KeysUrl == "https://www.kavel.ai/settings/apikeys"
