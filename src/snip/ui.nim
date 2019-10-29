import os
import strutils
import tables
import terminal
import sequtils

import ./compile
import ./globals
import ./keymap

when defined(windows):
  var BRIGHT = false
else:
  var BRIGHT = true

var COLORSTRING = """
  default = fgWhite
  dialog = fgYellow
  error = fgRed
  linenumber = fgYellow
  status = fgYellow

  comment = fgMagenta
  keyword = fgCyan
  number = fgGreen
  string = fgRed
"""

var COLORTABLE = newTable[string, ForegroundColor]()

template writeFlush(str: string) =
  stdout.write(str)
  stdout.flushFile()

proc colorHandler(name, value: string) =
  COLORTABLE[name] = parseEnum[ForegroundColor](value)

proc loadColors*() =
  loadMap(COLORSTRING, colorHandler)
  if fileExists(getAppDir() / "colors.txt"):
    COLORSTRING = "colors.txt".readFile()

  loadMap(COLORSTRING, colorHandler)

proc setCursorPosPortable(x, y: int) =
  setCursorPos(x, y)

proc clearScreen*() {.inline.} =
  when defined(windows):
    eraseScreen()
  else:
    writeFlush("\e[H\e[J")
  LINE = 0
  COL = 0
  setCursorPosPortable(COL, LINE)

proc dialog*(text: string) =
  setCursorPosPortable(0, HEIGHT-1)
  eraseLine()
  setForegroundColor(COLORTABLE["dialog"], BRIGHT)
  writeFlush(text)

proc popupMsg*(text: string) =
  dialog(text)
  sleep(1500)

proc eraseLeftDialog*() =
  terminal.cursorBackward()
  stdout.write(" ")
  terminal.cursorBackward()
  stdout.flushFile()

proc lcol*() =
  hideCursor()
  setCursorPosPortable(0, HEIGHT-1)
  eraseLine()
  setForegroundColor(COLORTABLE["status"], BRIGHT)
  var fn = if FILENAME != "": " | " & FILENAME else: ""
  writeFlush("$#x$# | $# | $# = HELP" % [$(LINE+COFFSET+1), $(COL+1), MODES[MODE]["name"], $getKeyFromAction(HELP)] & fn)
  setForegroundColor(COLORTABLE["default"])
  setCursorPosPortable(COL+MARGIN, LINE)
  if WINDOW != HEIGHT-1:
    showCursor()
  stdout.flushFile()

proc split() {.inline.} =
  setCursorPosPortable(0, HEIGHT-WINDOW)
  var s = ""
  for i in 0..WIDTH-1:
    s &= "_"
  writeFlush(s)
  setCursorPosPortable(COL, LINE)

proc lineno(line, errline: int): string {.inline.} =
  result = $(line+1) & " "
  while result.len() < MARGIN:
    result = " " & result
  if errline == line:
    result[0] = '>'

iterator tokenizer(chunk: string): string {.inline.} =
  var tok = ""
  var quote = false
  var squote = false
  for ch in chunk:
    if ch == '"':
      if not quote:
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
      if not squote:
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
    elif ch in {'`', '-', '=', '[', ']', ';', ',', '/', '~', '!',
          '@', '#', '$', '%', '^', '&', '*', '(', ')', '_',
          '+', '{', '}', ':', '<', '>', '?', ' '}:
      if tok != "":
        yield tok
        tok = ""
      yield $ch
    else:
      tok &= ch
  if tok != "":
    yield tok

proc writeTerm(line: string) =
  setCursorPosPortable(0, LINE)
  eraseLine()
  if MARGIN != 0:
    if ERRORINFO.line == LINE+COFFSET:
      setForegroundColor(COLORTABLE["error"], BRIGHT)
    else:
      setForegroundColor(COLORTABLE["linenumber"], BRIGHT)
    stdout.write(lineno(LINE+COFFSET, ERRORINFO.line))
    setForegroundColor(COLORTABLE["default"])
  var comment = false
  for tok in tokenizer(line):
    if isLanguage("comment", tok) or comment == true:
      comment = true
      setForegroundColor(COLORTABLE["comment"], BRIGHT)
    elif isLanguage("keyword", tok):
      setForegroundColor(COLORTABLE["keyword"], BRIGHT)
    elif tok.replace(".", "").all(isDigit):
      setForegroundColor(COLORTABLE["number"], BRIGHT)
    # elif tok.isAlphaNumeric():
    #   setForegroundColor(COLORTABLE["alpha"], BRIGHT)
    elif tok[0] in ['"', '\''] and tok[0] == tok[tok.len()-1]:
      setForegroundColor(COLORTABLE["string"], BRIGHT)
    stdout.write(tok)
    setForegroundColor(COLORTABLE["default"])
  stdout.flushFile()

proc writeCode*() {.inline.} =
  let ln = LINE

  var h = 0
  for i in COFFSET .. BUFFER.len()-1:
    LINE = h
    writeTerm(BUFFER[i].substr(0, WIDTH-MARGIN-1))
    if h == HEIGHT-WINDOW-1:
      break
    h += 1

  if LASTBUFFER.len() > BUFFER.len() and BUFFER.len()-1 < HEIGHT-WINDOW-1:
    setCursorPosPortable(0, h)
    eraseLine()

  LINE = ln
  setCursorPosPortable(COL+MARGIN, LINE)

proc clearOutput() {.inline.} =
  setCursorPosPortable(0, HEIGHT-WINDOW+1)
  for i in 1 .. WINDOW-2:
    eraseLine()
    terminal.cursorDown(1)
  setCursorPosPortable(0, HEIGHT-WINDOW+1)

proc writeOutputLines(output: seq[string], err = -1, offset=0) =
  var i = 0
  for line in output:
    if MARGIN != 0:
      if err == i:
        setForegroundColor(COLORTABLE["error"], BRIGHT)
      else:
        setForegroundColor(COLORTABLE["linenumber"], BRIGHT)
      stdout.write(lineno(offset+i, err))
    if err == i:
      setForegroundColor(COLORTABLE["error"])
    else:
      setForegroundColor(COLORTABLE["default"])
    echo line
    i += 1

proc redrawLine*() =
  hideCursor()
  writeTerm(BUFFER[LINE+COFFSET].substr(0, WIDTH-MARGIN-1))
  lcol()

proc writeOutput*() {.inline.} =
  if WINDOW == 0:
    return

  if getOutput() or LWOFFSET != WOFFSET or FORCE_REDRAW:
    let ln = LINE

    hideCursor()
    clearOutput()

    OUTLINES = WOUTPUT.len()
    if LWOFFSET == WOFFSET and ERRORINFO.outline != -1:
      while OUTLINES >= WINDOW and ERRORINFO.outline < OUTLINES-WINDOW-WOFFSET+2:
        WOFFSET += 1

    if OUTLINES > WINDOW-2:
      var st = OUTLINES-WINDOW+3
      if WOFFSET > st:
        st = 0
      else:
        st -= WOFFSET

      var ed = st+WINDOW-4
      if ed > OUTLINES-1:
        ed = OUTLINES-1

      var err = ERRORINFO.outline
      if err != -1:
        if err < st or err > ed:
          err = -1
        else:
          err = err - st

      writeOutputLines(WOUTPUT[st..ed], err, st)
    else:
      writeOutputLines(WOUTPUT, ERRORINFO.outline)

    if ERRORINFO.line != -1:
      LASTERRORLINE = ERRORINFO.line
      writeCode()
    elif LASTERRORLINE >= COFFSET and
      LASTERRORLINE < HEIGHT+COFFSET-1 and
      LASTERRORLINE < BUFFER.len()-1:
      LINE = LASTERRORLINE
      LASTERRORLINE = -1
      redrawLine()

    LINE = ln
    setCursorPosPortable(COL+MARGIN, LINE)
    showCursor()
    stdout.flushFile()

proc redraw*() =
  (WIDTH, HEIGHT) = terminalSize()

  hideCursor()
  if FORCE_REDRAW: clearScreen()

  writeCode()
  if FORCE_REDRAW:
    split()
    writeOutput()
  lcol()

  FORCE_REDRAW = false

proc writeHelp*(help: string) =
  clearScreen()
  var helpout = ""
  for line in help.splitLines():
    if line.strip() != "":
      if helpout == "":
        helpout = "  " & line
        while helpout.len() < (WIDTH div 2):
          helpout &= " "
      else:
        helpout &= line
        echo helpout
        helpout = ""
  if helpout != "":
    echo helpout
