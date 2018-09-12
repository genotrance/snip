import strutils
import tables
import threadpool

import ./globals
import ./keymap
import ./ui

var KCH*: Channel[seq[string]]
KCH.open()

when defined(windows):
  proc getch(): char {.header: "<conio.h>", importc: "getch".}
  proc kbhit(): int {.header: "<conio.h>", importc: "kbhit".}
else:
  {.compile: "getch.c".}

  proc enable_raw_mode() {.importc.}
  proc disable_raw_mode() {.importc.}
  proc getch(): char {.importc.}
  proc kbhit(): int {.importc.}

  proc cleanExit*() =
    disable_raw_mode()

proc getKey*(): seq[string] {.inline.} =
  result = @[]
  when not defined(windows):
    enable_raw_mode()

  var
    lchr: char
    code = ""

  while kbhit() != 0:
    lchr = getch()
    if lchr.int < 32 or lchr.int > 126:
      code = $(lchr.int)
      if lchr.int in {0, 27, 224}:
        while kbhit() != 0:
          lchr = getch()
          code &= $(lchr.int)
      result.add(code)
    else:
      result.add($(lchr.int))

  when not defined(windows):
    disable_raw_mode()

proc getDialogKey*(max=1, nl=true): string =
  result = ""
  var
    ready: bool
    codes: seq[string]

  while true:
    (ready, codes) = KCH.tryRecv()

    if ready:
      for code in codes:
        if KEYMAP.hasKey(code):
          let key = KEYMAP[code]
          case key
          of ENTER, CTRL_ENTER:
            return
          of BACKSPACE:
            if result.len() != 0:
              result = result.substr(0, result.len()-2)
              eraseLeftDialog()
          of ESC, CTRL_C:
            return ""
          else: discard
        else:
          if result.len() < max:
            let rcode = code.parseInt().char
            result &= rcode
            stdout.write(rcode)
            stdout.flushFile()
            if not nl:
              break

proc handleKey*() {.inline.} =
  var (ready, codes) = KCH.tryRecv()

  if ready:
    for code in codes:
      if KEYMAP.hasKey(code):
        let key = KEYMAP[code]
        if KEYACTION.hasKey(key):
          let ac = KEYACTION[key]
          if ACTIONMAP.hasKey(ac):
            ACTIONMAP[ac]()
      else:
        LASTCHAR = code.parseInt().char
        ACTIONMAP[DEFAULT]()
    lcol()

proc startKey() {.thread.} =
  while true:
    var codes = getKey()
    if codes.len() != 0:
      if not KCH.trySend(codes):
        echo "Unable to send key(s)"

proc setupKey*() =
  spawn startKey()

when isMainModule:
  var exit = false
  while not exit:
    for code in getKey():
      if code != "":
        echo "$#" % code
      if code.strip() == "27":
        exit = true
        break
