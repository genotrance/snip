import os
import tables

import snip/actions
import snip/globals
import snip/ui
import snip/undo

doLoad("snip.nimble")

template loop(call: proc(), count: int) =
    for i in 1 .. count:
        sleep(75)
        call()

template typeStr(str: string) =
    for i in str:
        sleep(75)
        LASTCHAR = i
        addChar()

# Cursor up/down/left/right
loop(cursorDown, 50)
loop(cursorUp, 50)
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

# Load nimc buffer
doLoad("""
for i in 0 .. 30:
    echo i

# Extra text for backspace
""")

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
loop(addNewline, 4)
typeStr("# Finally ending")
cursorTop()
sleep(750)

# Erase chars ahead/back
loop(eraseRight, 20)
cursorBottom()
loop(eraseLeft, 30)

doClear()

# Next/prev modes
loop(doNextMode, MODES.len())
loop(doPrevMode, MODES.len())

# Reset code
doLoad("""testing word era!se
back and forth, back and forth
up and down! left/right ()
""")

# Erase words ahead/back
loop(eraseRightWord, 5)
cursorDown()
cursorEnd()
loop(eraseLeftWord, 5)

sleep(1000)

doQuit()