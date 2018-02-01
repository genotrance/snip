import os
import posix
import strutils
import tables
import terminal

import ./compile
import ./gist
import ./globals
import ./key
import ./keymap
import ./ui
import ./undo

template BUFLINE: string = BUFFER[LINE+COFFSET]

# CTRL-combo

proc ctrlfuncLeft(kfunc: proc(redraw: bool), rfunc: proc()) =
    if COL > 0 and BUFLINE[COL-1] == ' ':
        while COL > 0 and BUFLINE[COL-1] == ' ':
            kfunc(redraw=false)
    if COL > 0 and BUFLINE[COL-1] != ' ':
        while COL > 0 and BUFLINE[COL-1] != ' ':
            kfunc(redraw=false)
    else:
        kfunc(redraw=false)
    rfunc()

proc ctrlfuncRight(kfunc: proc(redraw: bool), rfunc: proc()) =
    if COL < BUFLINE.len()-1 and BUFLINE[COL+1] == ' ':
        while COL < BUFLINE.len()-1 and BUFLINE[COL+1] == ' ':
            kfunc(redraw=false)
        kfunc(redraw=false)
    if COL < BUFLINE.len()-1 and BUFLINE[COL+1] != ' ':
        while COL < BUFLINE.len()-1 and BUFLINE[COL+1] != ' ':
            kfunc(redraw=false)
        kfunc(redraw=false)
    else:
        kfunc(redraw=false)
    rfunc()

# Cursor movement

proc cursorLeftHelper(redraw=true) =
    if COL > 0:
        COL -= 1
        if redraw: lcol()
    else:
        if LINE > 0:
            LINE -= 1
            COL = min(WIDTH-MARGIN-1, BUFLINE.len())
            if redraw: lcol()
        else:
            if COFFSET > 0:
                COFFSET -= 1
                COL = min(WIDTH-MARGIN-1, BUFLINE.len())
                if redraw: redraw()

proc cursorLeft*() =
    cursorLeftHelper()

proc cursorLeftWord*() =
    ctrlfuncLeft(cursorLeftHelper, lcol)

proc cursorDownHelper(redraw=true) =
    if LINE+COFFSET < BUFFER.len()-1:
        if LINE < HEIGHT-WINDOW-1:
            LINE += 1
            if COL > BUFLINE.len():
                COL = BUFLINE.len()
            if redraw: lcol()
        else:
            COFFSET += 1
            if redraw: redraw()

proc cursorDown*() =
    cursorDownHelper()

proc cursorRightHelper(redraw=true) =
    if COL < min(WIDTH-MARGIN-1, BUFLINE.len()):
        COL += 1
        if redraw: lcol()
    else:
        if LINE+COFFSET < BUFFER.len()-1:
            if LINE < HEIGHT-WINDOW-1:
                LINE += 1
                COL = 0
                if redraw: lcol()
            else:
                COFFSET += 1
                COL = 0
                if redraw: redraw()

proc cursorRight*() =
    cursorRightHelper()

proc cursorRightWord*() =
    ctrlfuncRight(cursorRightHelper, lcol)

proc cursorUpHelper(redraw=true) =
    if LINE > 0:
        LINE -= 1
        if COL > BUFLINE.len():
            COL = BUFLINE.len()
        if redraw: lcol()
    else:
        if COFFSET > 0:
            COFFSET -= 1
            if redraw: redraw()

proc cursorUp*() =
    cursorUpHelper()

proc cursorTop*() =
    COL = 0
    LINE = 0
    COFFSET = 0
    redraw()

proc cursorBottom*() =
    if BUFFER.len()-1 < HEIGHT-WINDOW-1:
        LINE = BUFFER.len()-1
        COL = min(WIDTH-MARGIN-1, BUFLINE.len())
        lcol()
    else:
        COFFSET = BUFFER.len()-1-HEIGHT+WINDOW+1
        LINE = HEIGHT-WINDOW-1
        COL = min(WIDTH-MARGIN-1, BUFFER[BUFFER.len()-1].len())
        redraw()

proc cursorEnd*() =
    COL = min(WIDTH-MARGIN-1, BUFLINE.len())
    lcol()

proc cursorStart*() =
    COL = 0
    lcol()

proc cursorPageDown*() =
    if LINE+COFFSET < BUFFER.len()-1:
        for i in 1 .. (HEIGHT-WINDOW).shr(1)-1:
            cursorDownHelper(false)
        redraw()

proc cursorPageUp*() =
    if LINE+COFFSET > 0:
        for i in 1 .. (HEIGHT-WINDOW).shr(1)-1:
            cursorUpHelper(false)
        redraw()

# Output window

proc scrollWindowDown*() =
    WOFFSET -= 1
    if WOFFSET < 0:
        WOFFSET = 0

proc scrollWindowUp*() =
    WOFFSET += 1
    if WOFFSET > OUTLINES-WINDOW+2:
        WOFFSET = OUTLINES-WINDOW+2

# Actions

proc doQuit*() =
    clearScreen()
    cleanup()
    when not defined(windows):
        cleanExit()
    quit(0)

proc doRun*() =
    compile()

proc doRedraw*() =
    FORCE_REDRAW = true
    redraw()

proc doHelp*() =
    writeHelp(getKeyHelp())
    discard getDialogKey(nl=false)
    doRedraw()

proc doLoad*(src: string, build=true) =
    FILENAME = ""
    if fileExists(src):
        BUFFER = src.readFile().splitLines()
        FILENAME = src
    elif isUrl(src):
        let body = getGist(src)
        if body != "":
            BUFFER = body.splitLines()
            FILENAME = src
        else:
            popupMsg("URL failed to load: " & src)
    else:
        BUFFER = src.splitLines()
    if build: compile()
    doRedraw()

proc doLoadDialog*() =
    dialog("Load file: ")
    let fn = getDialogKey(WIDTH-10)
    if fn != "":
        if (not isUrl(fn)) and (not fileExists(fn)):
            popupMsg("File not found: " & fn)
        else:
            doLoad(fn)

proc doSave(dst: string) =
    dialog("Saving ...")
    if "gist://" == dst:
        let url = createGist()
        if url != "":
            FILENAME = url
        else:
            popupMsg("Create gist failed")
            return
    else:
        let f = open(dst, fmWrite)
        f.write(BUFFER.join("\n"))
        f.close()
        FILENAME = dst
    popupMsg("Saved to " & FILENAME)

proc doSaveAs*()
proc doSaveDialog*() =
    if isUrl(FILENAME):
        doSaveAs()
        return

    if FILENAME != "":
        doSave(FILENAME)
        return

    dialog("Save to: ")
    let fn = getDialogKey(WIDTH-10)
    var yn = "y"

    if fn == "":
        return
    elif fileExists(fn):
        dialog("Overwrite [y/N]: ")
        yn = getDialogKey(nl=false).toLowerAscii()
    
    if yn == "y":
        doSave(fn)

proc doSaveAs*() =
    let fn = FILENAME
    FILENAME = ""

    doSaveDialog()

    if FILENAME == "":
        FILENAME = fn

proc doCreateGist*() =
    doSave("gist://")

proc doClear*() =
    doLoad("")

proc doNextMode*() =
    setMode(true)
    lcol()

proc doPrevMode*() =
    setMode(false)
    lcol()

proc doToggleLineNo*() =
    if MARGIN != 0:
        MARGIN = 0
    else:
        MARGIN = D_MARGIN
    redraw()

# Removing chars

proc eraseLeftHelper(redraw=true) =
    let ln = BUFLINE.len()
    if COL != 0:
        if COL == ln:
            BUFLINE = BUFLINE.substr(0, ln-2)
        else:
            BUFLINE = BUFLINE.substr(0, COL-2) & BUFLINE.substr(COL)
        COL -= 1
        if redraw: redrawLine()
    else:
        if LINE > 0 or COFFSET > 0:
            COL = BUFFER[LINE+COFFSET-1].len()
            BUFFER[LINE+COFFSET-1] = BUFFER[LINE+COFFSET-1] & BUFLINE
            BUFFER.delete(LINE+COFFSET)
            if COFFSET > 0:
                COFFSET -= 1
            elif LINE > 0:
                LINE -= 1
            if COL > WIDTH-MARGIN-1:
                COL = WIDTH-MARGIN-1
            if redraw: redraw()

proc eraseLeft*() =
    eraseLeftHelper()

proc eraseLeftWord*() =
    ctrlfuncLeft(eraseLeftHelper, redraw)

proc eraseLeftLine*() =
    for i in 0 .. COL-1:
        eraseLeftHelper(false)
    COL = 0
    redrawLine()

proc eraseRightHelper(redraw=true) =
    if COL < BUFLINE.len():
        BUFLINE.delete(COL, COL)
        if redraw: redrawLine()
    else:
        if LINE+COFFSET < BUFFER.len()-1:
            BUFLINE = BUFLINE & BUFFER[LINE+COFFSET+1]
            BUFFER.delete(LINE+COFFSET+1)
            if COFFSET > 0:
                COFFSET -= 1
            if redraw: redraw()

proc eraseRight*() =
    eraseRightHelper()

proc eraseRightWord*() =
    ctrlfuncRight(eraseRightHelper, redraw)

proc eraseRightLine*() =
    for i in COL .. BUFLINE.len()-1:
        eraseRightHelper(false)
    redrawLine()

# Adding chars

proc addNewline*() =
    if COL <= BUFLINE.len():
        let br = BUFLINE.substr(COL)
        BUFLINE = BUFLINE.substr(0, COL-1)
        if COL == BUFLINE.len()-1:
            BUFFER.insert("", LINE+COFFSET+1)
        else:
            BUFFER.insert(br, LINE+COFFSET+1)
        if LINE == HEIGHT-WINDOW-1:
            COFFSET += 1
        else:
            LINE += 1
        COL = 0
        redraw()

proc addChar*() =
    if COL == BUFLINE.len():
        BUFLINE &= LASTCHAR
    elif COL < BUFLINE.len():
        let br = BUFLINE.substr(COL)
        BUFLINE = BUFLINE.substr(0, COL-1) & LASTCHAR & br
    COL += 1
    if COL > WIDTH-MARGIN-1:
        COL = WIDTH-MARGIN-1
    redrawLine()

proc addSpace() =
    LASTCHAR = ' '
    addChar()

proc add2Space() =
    for i in 0 .. 1: addSpace()

proc add4Space() =
    for i in 0 .. 3: addSpace()

proc add8Space() =
    for i in 0 .. 7: addSpace()
            
proc loadActions*() =
    ACTIONMAP[CURSOR_UP] = cursorUp
    ACTIONMAP[CURSOR_DOWN] = cursorDown
    ACTIONMAP[CURSOR_LEFT] = cursorLeft
    ACTIONMAP[CURSOR_RIGHT] = cursorRight
    ACTIONMAP[CURSOR_LEFT_WORD] = cursorLeftWord
    ACTIONMAP[CURSOR_RIGHT_WORD] = cursorRightWord
    ACTIONMAP[CURSOR_PAGEUP] = cursorPageUp
    ACTIONMAP[CURSOR_PAGEDOWN] = cursorPageDown
    ACTIONMAP[CURSOR_START] = cursorStart
    ACTIONMAP[CURSOR_END] = cursorEnd
    ACTIONMAP[CURSOR_TOP] = cursorTop
    ACTIONMAP[CURSOR_BOTTOM] = cursorBottom
    ACTIONMAP[WINDOW_DOWN] = scrollWindowDown
    ACTIONMAP[WINDOW_UP] = scrollWindowUp
    ACTIONMAP[ERASE_LEFT] = eraseLeft
    ACTIONMAP[ERASE_RIGHT] = eraseRight
    ACTIONMAP[ERASE_LEFT_WORD] = eraseLeftWord
    ACTIONMAP[ERASE_RIGHT_WORD] = eraseRightWord
    ACTIONMAP[ERASE_LEFT_LINE] = eraseLeftLine
    ACTIONMAP[ERASE_RIGHT_LINE] = eraseRightLine
    ACTIONMAP[NEWLINE] = addNewline
    ACTIONMAP[CLEAR_SCREEN] = doClear
    ACTIONMAP[CREATE_GIST] = doCreateGist
    ACTIONMAP[LOAD_FILE] = doLoadDialog
    ACTIONMAP[HELP] = doHelp
    ACTIONMAP[NEXT_MODE] = doNextMode
    ACTIONMAP[PREV_MODE] = doPrevMode
    ACTIONMAP[QUIT] = doQuit
    ACTIONMAP[REDO] = doRedo
    ACTIONMAP[REDRAW] = doRedraw
    ACTIONMAP[RUN] = doRun
    ACTIONMAP[SAVE_FILE] = doSaveDialog
    ACTIONMAP[SAVE_AS] = doSaveAs
    ACTIONMAP[TO_2_SPACES] = add2Space
    ACTIONMAP[TO_4_SPACES] = add4Space
    ACTIONMAP[TO_8_SPACES] = add8Space
    ACTIONMAP[TOGGLE_LINES] = doToggleLineNo
    ACTIONMAP[UNDO] = doUndo
    ACTIONMAP[DEFAULT] = addChar

    when not defined(windows):
        if KEYACTION.hasKey(CTRL_C) and ACTIONMAP.hasKey(KEYACTION[CTRL_C]):
            onSignal(SIGINT):
                ACTIONMAP[KEYACTION[CTRL_C]]()
        
        if KEYACTION.hasKey(CTRL_Z) and ACTIONMAP.hasKey(KEYACTION[CTRL_Z]):
            onSignal(SIGTSTP):
                ACTIONMAP[KEYACTION[CTRL_Z]]()
                redraw()
        
