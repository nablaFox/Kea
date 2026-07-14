import core
import input

type
  Frame* = object
    delta*: float32
    input*: Input

iterator frames*(kea: Kea): Frame =
  discard

proc render*(kea: Kea) =
  discard
