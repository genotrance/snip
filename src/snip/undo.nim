import ./globals
import ./ui

var HISTORY: seq[seq[string]] = @[]
var CHISTORY: seq[seq[int]] = @[]
var REDO: seq[seq[string]] = @[]
var CREDO: seq[seq[int]] = @[]
var LASTCURSOR: seq[int] = @[0, 0]

proc backup*() {.inline.} =
  if LASTBUFFER != BUFFER:
    REDO = @[]
    CREDO = @[]
    HISTORY.add(LASTBUFFER)
    CHISTORY.add(LASTCURSOR)
    if HISTORY.len() > MAXHISTORY:
      HISTORY.delete(0)
      CHISTORY.delete(0)

    LASTBUFFER = BUFFER
    LASTCURSOR = @[LINE, COL]

  LCOFFSET = COFFSET
  LWOFFSET = WOFFSET

proc doUndo*() =
  if HISTORY.len() != 0:
    REDO.add(BUFFER)
    CREDO.add(@[LINE, COL])
    BUFFER = HISTORY.pop()
    LASTBUFFER = BUFFER
    let ch = CHISTORY.pop()
    LINE = ch[0]
    COL = ch[1]
    LASTCURSOR = @[LINE, COL]
    redraw()

proc doRedo*() =
  if REDO.len() != 0:
    HISTORY.add(BUFFER)
    CHISTORY.add(@[LINE, COL])
    BUFFER = REDO.pop()
    LASTBUFFER = BUFFER
    let cr = CREDO.pop()
    LINE = cr[0]
    COL = cr[1]
    LASTCURSOR = @[LINE, COL]
    redraw()
