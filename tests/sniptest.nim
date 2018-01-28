import os
import strutils
import tables

import snip/actions
import snip/globals
import snip/ui
import snip/undo

template loop(call: proc(), count: int) =
    for i in 1 .. count:
        sleep(75)
        call()

template typeStr(str: string) =
    for i in str:
        sleep(75)
        LASTCHAR = i
        addChar()

proc test1() =
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
# Scroll output window
# Newline scrolls
# Delete and backspace test
    """)
    sleep(750)

    # Line numbers
    doToggleLineNo()
    sleep(750)
    doToggleLineNo()

    # Execution
    doRun()

    # Scroll output window
    loop(scrollWindowUp, 10)
    loop(scrollWindowDown, 10)

    # Output stays
    cursorBottom()
    loop(addNewline, 4)
    typeStr("# Adding another comment")
    loop(addNewline, HEIGHT-WINDOW-4)
    typeStr("# Finally ending")
    cursorTop()
    sleep(750)

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

var runtests = 1
var tests = @[test1, test2, test3]
if commandLineParams().len() > 0:
    runtests = parseInt(commandLineParams()[0])
for i in runtests-1 .. tests.len()-1:
    tests[i]()

sleep(1000)

doQuit()