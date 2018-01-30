import tables

const VERSION* {.strdefine.} = ""

# Size of terminal
var WIDTH* = 0
var HEIGHT* = 0

# Position of cursor
var LINE* = 0
var COL* = 0

# Code window
const D_MARGIN* = 5
var COFFSET* = 0        # Scroll position
var LCOFFSET* = 0       # Last scroll position
var LASTCHAR*: char     # Last character typed
var MARGIN* = D_MARGIN  # space for line numbers

# Output window
var WINDOW* = 10        # Window size
var WOFFSET* = 0        # Scroll position
var LWOFFSET* = 0       # Last scroll position
var OUTLINES* = 0       # Number of lines in output

# Settings
var MAXHISTORY* = 100   # max number of undo/redo
var MODE* = "nc"        # Backend mode

# Debugging
var DEBUG* = false

# Content
var BUFFER* = @[""]
var LASTBUFFER* = @[""]
var LASTOUTPUT* = ""
var MODES* = initOrderedTable[string, Table[string, string]]()
var FORCE_REDRAW* = true

template log*(str: string) =
    let f = open("snip.log", fmAppend)
    f.writeLine(str)
    f.flushFile()
    f.close()