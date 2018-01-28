import os
import strutils
import tables
import terminal

import ./compile
import ./globals
import ./keymap

when defined(windows):
    var BRIGHT = false
else:
    var BRIGHT = true
    
proc setCursorPosReset(x, y: int) =
    when not defined(windows):
        setCursorPos(x+1, y+1)
    else:
        setCursorPos(x, y)

proc clearScreen*() {.inline.} =
    when defined(windows):
        eraseScreen()
    else:
        stdout.write("\e[H\e[J")
    LINE = 0
    COL = 0
    setCursorPosReset(COL, LINE)

proc lcol*() =
    hideCursor()
    setCursorPos(COL, HEIGHT-1)
    eraseLine()
    setForegroundColor(fgYellow, BRIGHT)
    stdout.write("$#x$#    $#    $# = HELP" % [$(LINE+COFFSET+1), $(COL+1), MODES[MODE]["name"], $getKeyFromAction(HELP)])
    if DEBUG:
        stdout.write("    " & STATUS)
    setForegroundColor(fgWhite)
    setCursorPosReset(COL+MARGIN, LINE)
    showCursor()

proc split() {.inline.} =
    setCursorPos(0, HEIGHT-WINDOW)
    var s = ""
    for i in 0..WIDTH-1:
        s &= "_"
    stdout.write(s)
    setCursorPosReset(COL, LINE)

proc lineno(): string {.inline.} =
    result = $(LINE+COFFSET+1) & " "
    while result.len() < MARGIN:
        result = " " & result

iterator tokenizer(chunk: string): string {.inline.} =
    var tok = ""
    var quote = false
    var squote = false
    for ch in chunk:
        if ch == '"':
            if quote == false:
                if tok != "":
                    yield tok
                    tok = ""
                quote = true
                tok &= ch
            else:
                tok &= ch
                quote = false
                yield tok
                tok = ""
        elif ch == '\'':
            if squote == false:
                if tok != "":
                    yield tok
                    tok = ""
                squote = true
                tok &= ch
            else:
                tok &= ch
                squote = false
                yield tok
                tok = ""
        elif quote or squote:
            tok &= ch
        elif ch in "`-=[];,/~!@#$%^&*()_+{}:<>? ":
            if tok != "":
                yield tok
                tok = ""
            yield $ch
        else:
            tok &= ch
    if tok != "":
        yield tok

proc writeTerm(line: string) =
    setCursorPos(0, LINE)
    eraseLine()
    if MARGIN != 0:
        setForegroundColor(fgYellow, BRIGHT)
        stdout.write(lineno())
        setForegroundColor(fgWhite)
    var comment = false
    for tok in tokenizer(line):
        if isLanguage("comment", tok) or comment == true:
            comment = true
            setForegroundColor(fgMagenta, BRIGHT)
        elif isLanguage("keyword", tok):
            setForegroundColor(fgCyan, BRIGHT)
        elif tok.replace(".", "").isDigit():
            setForegroundColor(fgGreen, BRIGHT)
        # elif tok.isAlphaNumeric():
        #     setForegroundColor(fgYellow, BRIGHT)
        elif tok[0] in ['"', '\''] and tok[0] == tok[tok.len()-1]:
            setForegroundColor(fgRed, BRIGHT)
        stdout.write(tok)
        setForegroundColor(fgWhite)

proc writeCode*() {.inline.} =
    let ln = LINE

    var h = 0
    for i in COFFSET .. BUFFER.len()-1:
        LINE = h
        writeTerm(BUFFER[i].substr(0, WIDTH-MARGIN-1))
        if h == HEIGHT-WINDOW-1:
            break
        h += 1

    if LASTBUFFER.len() > BUFFER.len() and BUFFER.len() < HEIGHT-WINDOW-1:
        setCursorPos(0, h)
        eraseLine()

    LINE = ln
    setCursorPosReset(COL+MARGIN, LINE)

proc writeOutput*() {.inline.} =
    let output = getOutput()
    if output != "":
        let ln = LINE

        hideCursor()        
        setCursorPos(0, HEIGHT-WINDOW+1)

        let o = output.splitLines()
        OUTLINES = o.len()
        if OUTLINES > WINDOW-2:
            var st = OUTLINES-WINDOW+2
            if WOFFSET > st:
                st = 0
            else:
                st -= WOFFSET

            var ed = st+WINDOW-4
            if ed > OUTLINES-1:
                ed = OUTLINES-1
            
            echo o[st..ed].join("\n")
        else:
            echo o.join("\n")

        LINE = ln
        setCursorPosReset(COL+MARGIN, LINE)
        showCursor()

proc redraw*() =
    (WIDTH, HEIGHT) = terminalSize()

    hideCursor()
    if FORCE_REDRAW: clearScreen()

    writeCode()
    if FORCE_REDRAW: split()
    writeOutput()
    lcol()

    FORCE_REDRAW = false

proc redrawLine*() =
    hideCursor()
    writeTerm(BUFFER[LINE+COFFSET].substr(0, WIDTH-MARGIN-1))
    lcol()

proc writeHelp*(help: string) =
    clearScreen()
    echo help
    discard getch()
    redraw()
