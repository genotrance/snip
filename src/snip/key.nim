import strutils
import tables

import ./globals
import ./keymap
import ./ui

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

proc getKey*(): string {.inline.} =
    result = ""
    when not defined(windows):
        enable_raw_mode()
    
    LASTCHAR = getch()
    result = $LASTCHAR.int
    while kbhit() != 0:
        LASTCHAR = getch()
        result &= $LASTCHAR.int

    when not defined(windows):
        disable_raw_mode()
 
proc handleKey*() =
    var code = getKey()
    
    if code != "":
        if KEYMAP.hasKey(code):
            let key = KEYMAP[code]
            STATUS = $key & " " & code
            if KEYACTION.hasKey(key):
                let ac = KEYACTION[key]
                if ACTIONMAP.hasKey(ac):
                    ACTIONMAP[ac]()
        else:
            ACTIONMAP[DEFAULT]()
            STATUS = $DEFAULT & " " & code
        lcol()

when isMainModule:
    while true:
        var code = getKey()
        if code != "":
            echo code
        if code == "27":
            break
