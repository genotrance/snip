import algorithm
import os
import ospaths
import strutils
import tables

import ./globals

type
  KEYS* = enum
    ESC, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12,
    BACKSPACE, INSERT, HOME, PAGEUP,
    TAB, ENTER, DELETE, END, PAGEDOWN,
    UP, LEFT, DOWN, RIGHT,

    SHIFT_F1, SHIFT_F2, SHIFT_F3, SHIFT_F4, SHIFT_F5, SHIFT_F6,
    SHIFT_F7, SHIFT_F8, SHIFT_F9, SHIFT_F10, SHIFT_F11, SHIFT_F12,
    SHIFT_INSERT,

    CTRL_F1, CTRL_F2, CTRL_F3, CTRL_F4, CTRL_F5, CTRL_F6,
    CTRL_F7, CTRL_F8, CTRL_F9, CTRL_F10, CTRL_F11, CTRL_F12,
    CTRL_BACKSPACE, CTRL_INSERT, CTRL_HOME, CTRL_PAGEUP,
    CTRL_TAB, CTRL_ENTER, CTRL_DELETE, CTRL_END, CTRL_PAGEDOWN,
    CTRL_UP, CTRL_LEFT, CTRL_DOWN, CTRL_RIGHT,

    CTRL_A, CTRL_B, CTRL_C, CTRL_D, CTRL_E, CTRL_F, CTRL_G, CTRL_H,
    CTRL_I, CTRL_J, CTRL_K, CTRL_L, CTRL_M, CTRL_N, CTRL_O, CTRL_P,
    CTRL_Q, CTRL_R, CTRL_S, CTRL_T, CTRL_U, CTRL_V, CTRL_W, CTRL_X,
    CTRL_Y, CTRL_Z,

    ALT_F1, ALT_F2, ALT_F3, ALT_F4, ALT_F5, ALT_F6,
    ALT_F7, ALT_F8, ALT_F9, ALT_F10, ALT_F11, ALT_F12,
    ALT_INSERT, ALT_HOME, ALT_PAGEUP,
    ALT_DELETE, ALT_END, ALT_PAGEDOWN,
    ALT_UP, ALT_LEFT, ALT_DOWN, ALT_RIGHT

type
  ACTIONS* = enum
    CURSOR_UP, CURSOR_DOWN, CURSOR_LEFT, CURSOR_RIGHT,
    CURSOR_LEFT_WORD, CURSOR_RIGHT_WORD,
    CURSOR_PAGEUP, CURSOR_PAGEDOWN,
    CURSOR_START, CURSOR_END, CURSOR_TOP, CURSOR_BOTTOM,

    WINDOW_DOWN, WINDOW_UP,

    ERASE_LEFT, ERASE_RIGHT, ERASE_LEFT_WORD, ERASE_RIGHT_WORD,
    ERASE_LEFT_LINE, ERASE_RIGHT_LINE,

    NEWLINE,

    CLEAR_SCREEN, CREATE_GIST, FULL_SCREEN_CODE, FULL_SCREEN_OUTPUT, HELP,
    LOAD_FILE, NEXT_MODE, PREV_MODE, QUIT, REDO, REDRAW, RUN, SAVE_FILE,
    SAVE_AS, TO_2_SPACES, TO_4_SPACES, TO_8_SPACES, TOGGLE_LINES, UNDO,

    DEFAULT

var ACTIONMAP* = initTable[ACTIONS, proc()]()
var KEYMAP* = initTable[string, KEYS]()
var KEYACTION* = initTable[KEYS, ACTIONS]()

const TERMS = @["cygwin", "macos", "putty", "windows", "xterm"]
const KEYMAPSTRING_TABLE = (block:
  var kmtb = initTable[string, string]()
  for term in TERMS:
    kmtb[term] = staticRead("term"/term&".txt")

  kmtb
)

var KEYACTIONSTRING = """
  ESC = QUIT
  F2 = SAVE_FILE
  F3 = LOAD_FILE
  F4 = SAVE_AS
  F5 = RUN
  SHIFT_F6 = PREV_MODE
  F6 = NEXT_MODE
  F7 = TOGGLE_LINES
  F8 = CREATE_GIST
  F10 = HELP
  F11 = FULL_SCREEN_CODE
  F12 = FULL_SCREEN_OUTPUT

  CTRL_C = QUIT
  CTRL_R = REDRAW
  CTRL_W = CLEAR_SCREEN
  CTRL_Y = REDO

  UP = CURSOR_UP
  LEFT = CURSOR_LEFT
  DOWN = CURSOR_DOWN
  RIGHT = CURSOR_RIGHT

  ALT_UP = WINDOW_UP
  ALT_DOWN = WINDOW_DOWN

  CTRL_LEFT = CURSOR_LEFT_WORD
  CTRL_RIGHT = CURSOR_RIGHT_WORD

  HOME = CURSOR_START
  END = CURSOR_END
  PAGEUP = CURSOR_PAGEUP
  PAGEDOWN = CURSOR_PAGEDOWN

  CTRL_HOME = CURSOR_TOP
  CTRL_END = CURSOR_BOTTOM

  BACKSPACE = ERASE_LEFT
  DELETE = ERASE_RIGHT
  CTRL_BACKSPACE = ERASE_LEFT_WORD
  CTRL_DELETE = ERASE_RIGHT_WORD
  CTRL_E = ERASE_LEFT_LINE
  CTRL_D = ERASE_RIGHT_LINE

  TAB = TO_2_SPACES
  ENTER = NEWLINE
  CTRL_ENTER = NEWLINE
"""

when defined(windows):
  KEYACTIONSTRING &= """
    CTRL_Z = UNDO
  """
else:
  KEYACTIONSTRING &= """
    CTRL_U = UNDO
  """

proc keyMapHandler(name, value: string) =
  let key = parseEnum[KEYS](name)
  if KEYMAP.hasKey(value) and KEYMAP[value] != key:
    if DEBUG:
      echo "Duplicate key code: " & value
      discard stdin.readline()
  KEYMAP[value] = key

proc keyActionHandler(name, value: string) =
  let key = parseEnum[KEYS](name)
  let action = parseEnum[ACTIONS](value)
  if KEYACTION.hasKey(key):
    echo "Duplicate key: " & $key
    quit()
  KEYACTION[key] = action

proc loadMap(mapstring: string, handler: proc(name, value: string)) =
  for ln in mapstring.splitLines():
    let line = ln.strip()
    if line.len() == 0 or line[0] == '#':
      continue

    let entries = line.split(",")
    for entry in entries:
      if entry.strip() == "": continue

      let nv = entry.split("=")
      if nv.len() != 2:
        echo "Bad nv pair: " & line
        quit()
      let nm = nv[0].strip()
      let val = nv[1].strip()

      try:
        handler(nm, val)
      except:
        echo "Failed to parse: " & line
        quit()

proc loadMaps*() =
  when defined(windows):
    loadMap(KEYMAPSTRING_TABLE["windows"], keyMapHandler)
  else:
    for km in KEYMAPSTRING_TABLE.keys():
      if km != "windows":
        loadMap(KEYMAPSTRING_TABLE[km], keyMapHandler)

  if fileExists(getAppDir() / "keymap.txt"):
    KEYACTIONSTRING = "keymap.txt".readFile()
  loadMap(KEYACTIONSTRING, keyActionHandler)

proc getKeyFromAction*(action: ACTIONS): KEYS =
  for k, a in KEYACTION.pairs:
    if a == action:
      return k

proc getKeyHelp*(): string =
  result = ""
  var keys = newSeq[KEYS]()
  for key in KEYACTION.keys():
    keys.add(key)
  for key in keys.sorted(system.cmp[KEYS]):
    result &= ($key).replace("_", "-") & " = " & ($(KEYACTION[key])).replace("_", " ") & "\n"

proc getActionHelp*(): string =
  result = ""
  var keyacts = newSeq[string]()
  for key in KEYACTION.keys():
    keyacts.add(($(KEYACTION[key])).replace("_", " ") & " = " & ($key).replace("_", "-"))
  for keyact in keyacts.sorted(system.cmp[string]):
    result &= keyact & "\n"
