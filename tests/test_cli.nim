import std/[strutils]
import entlint

proc main() =
  # Entropie basse
  doAssert shannonEntropy("aaaaaaaaaaaaaaaaaaaa") < 1.0

  # Entropie haute → doit produire un aperçu
  let s = "prefix_" &
          "9aZ2Qm!X#C7yP0kV4uR3tY8wS1bL5nH6qJ2zD9eF0gM" &
          "_suffix"
  let pv = findPreview(s, win=16, thr=3.5)
  doAssert pv.len > 0, "preview must not be empty"

main()
