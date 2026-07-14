import core
import keys

type
  Input* = object
    state: ref KeaState

proc keyPressed*(input: Input, key: Key): bool =
  input.state.currentKeys[key] and
    not input.state.previousKeys[key]
