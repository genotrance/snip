import os
import strutils
import tables

import snip/actions
import snip/compile
import snip/globals
import snip/ui
import snip/undo

template loop(call: proc(), count: int) =
    for i in 1 .. count:
        sleep(75)
        call()

template typeStr(str: string) =
    for i in str:
        sleep(15)
        LASTCHAR = i
        addChar()

proc test1() =
    doHelp()
    sleep(750)

    doLoad("snip.nimble")

    # Cursor up/down/left/right
    loop(cursorDown, HEIGHT-WINDOW+5)
    loop(cursorUp, HEIGHT-WINDOW+5)
    loop(cursorRight, 50)
    loop(cursorLeft, 50)

    # Beginning/End of line
    cursorEnd()
    sleep(750)
    cursorStart()
    sleep(750)

    # Top/bottom of buffer
    cursorBottom()
    sleep(750)
    cursorTop()
    sleep(750)

    # Page-wise
    loop(cursorPageDown, 5)
    loop(cursorPageUp, 5)

proc test2() =
    # Load nimc buffer
    doLoad("""
for i in 0 .. 30:
    echo i

# Toggle line numbers
# Newline scrolls
# Display and scroll output window
# Delete and backspace test
    """)
    doRun()
    sleep(750)

    # Line numbers
    doToggleLineNo()
    sleep(750)
    doToggleLineNo()

    # Output stays
    cursorBottom()
    loop(addNewline, 4)
    typeStr("# Adding another comment")
    loop(addNewline, HEIGHT-WINDOW-4)
    typeStr("# Finally ending")
    cursorTop()
    sleep(750)

    # Scroll output window
    writeOutput()
    sleep(75)
    for i in 0 .. 5:
        scrollWindowUp()
        writeOutput()
        sleep(75)
    for i in 0 .. 5:
        scrollWindowDown()
        writeOutput()
        sleep(75)

    # Erase chars ahead/back
    loop(eraseRight, 20)
    cursorBottom()
    loop(eraseLeft, 30)

proc test3() =
    doClear()
    sleep(750)
    doLoad("# Prev / next mode")

    # Next/prev modes
    loop(doNextMode, MODES.len())
    loop(doPrevMode, MODES.len())

    # Reset code
    doLoad("""testing word era!se
back and forth, back and forth
up and down! left/right ()

Erase beginning of line from middle
Erase rest of line from middle
Erase full line from the beginning
Erase full line from end""")

    # Erase words ahead/back
    loop(eraseRightWord, 5)
    sleep(750)
    cursorDown()
    cursorEnd()
    loop(eraseLeftWord, 5)
    sleep(750)
    cursorBottom()
    eraseLeftLine()
    sleep(750)
    cursorUp()
    cursorStart()
    eraseRightLine()
    sleep(750)
    cursorUp()
    loop(cursorRight, 10)
    eraseRightLine()
    sleep(750)
    cursorUp()
    eraseLeftLine()

# Run compiler thread
setupCompiler()

var starttest = 1
var endtest = 3
var tests = @[test1, test2, test3]
if commandLineParams().len() > 0:
    starttest = parseInt(commandLineParams()[0])
if commandLineParams().len() > 1:
    endtest = parseInt(commandLineParams()[1])
for i in starttest-1 .. min(endtest-1, tests.len()-1):
    tests[i]()

sleep(1000)

doQuit()
