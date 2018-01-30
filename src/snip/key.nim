import strutils
import tables
import threadpool

import ./globals
import ./keymap
import ./ui

var KCH*: Channel[string]
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

proc getDialogKey*(max=1, nl=true): string =
    result = ""
    var ready: bool
    var code: string
    while true:
        (ready, code) = KCH.tryRecv()
        
        if ready:
            if KEYMAP.hasKey(code):
                let key = KEYMAP[code]
                if key in [ENTER, CTRL_ENTER]:
                    return
                elif key == BACKSPACE:
                    if result.len() != 0:
                        result = result.substr(0, result.len()-2)
                        eraseLeftDialog()
                elif key in [ESC, CTRL_C]:
                    return ""
            else:
                if result.len() < max:
                    let rcode = code.parseInt().char
                    result &= rcode
                    stdout.write(rcode)
                    stdout.flushFile()
                    if not nl:
                        break

proc handleKey*() =
    var (ready, code) = KCH.tryRecv()
    
    if ready:
        if KEYMAP.hasKey(code):
            let key = KEYMAP[code]
            if KEYACTION.hasKey(key):
                let ac = KEYACTION[key]
                if ACTIONMAP.hasKey(ac):
                    ACTIONMAP[ac]()
        else:
            ACTIONMAP[DEFAULT]()
        lcol()

proc startKey() {.thread.} =
    var code = ""
    while true:
        code = getKey()
        if code != "":
            if not KCH.trySend(code):
                echo "Unable to send key"

proc setupKey*() =
    spawn startKey()

when isMainModule:
    while true:
        var code = getKey()
        if code != "":
            echo code
        if code == "27":
            break
