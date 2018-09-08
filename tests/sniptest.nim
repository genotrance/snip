import os
import strutils
import tables

import snip/actions
import snip/compile
import snip/globals
import snip/keymap
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

template waitOutput() =
  while WOUTPUT[0] == "":
    sleep(100)
    writeOutput()
  sleep(3000)
  WOUTPUT = @[""]

proc test1() =
  writeHelp(getKeyHelp())
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
# Delete and backspace test""")
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

  # Left key scrolls up
  while COFFSET != 4:
    cursorUp()
  loop(cursorLeft, 30)
  cursorTop()

  # Right key scrolls down
  loop(cursorDown, HEIGHT-WINDOW)
  loop(cursorRight, 30)
  sleep(750)

  # Scroll output window
  writeOutput()
  sleep(75)
  for i in 0 .. 5:
    LWOFFSET = WOFFSET
    scrollWindowUp()
    writeOutput()
    sleep(75)
  for i in 0 .. 5:
    LWOFFSET = WOFFSET
    scrollWindowDown()
    writeOutput()
    sleep(75)

  # Erase chars ahead/back
  cursorTop()
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

proc test4() =
  doLoad("https://gist.github.com/9258b84dcd97e573403ce27e801d6ad5")
  sleep(750)

  doLoad("https://pastebin.com/pgiyRMPw")
  sleep(750)

  doLoad("https://gist.github.com/anonymous/9258b84dcd97e573403ce27e801d6ad5")
  sleep(750)

proc test5() =
  doClear()

  # Nim compiles
  doLoad("""echo "Hello world" """)
  waitOutput()

  # Nim doesn't compile
  doLoad("""echo i""")
  waitOutput()

  loop(doNextMode, 5)

  # Python executes
  doLoad("""print('Hello world')""")
  waitOutput()

  # Python fails
  doLoad("""print A""")
  waitOutput()

  loop(doNextMode, 2)

  # GCC compiles
  doLoad("""int main() { printf("Hello world"); }""")
  waitOutput()

  # GCC doesn't compile
  doLoad("echo")
  waitOutput()

  doNextMode()

  # G++ compiles
  doLoad("""
#include <iostream>
using namespace std;

int main() { cout << "Hello world"; }
""")
  waitOutput()

  # G++ doesn't compile
  doLoad("echo")
  waitOutput()

# Run compiler thread
setupCompiler()

var starttest = 1
var tests = @[test1, test2, test3, test4, test5]
var endtest = tests.len()
if commandLineParams().len() > 0:
  starttest = parseInt(commandLineParams()[0])
if commandLineParams().len() > 1:
  endtest = parseInt(commandLineParams()[1])
for i in starttest-1 .. min(endtest-1, tests.len()-1):
  tests[i]()

sleep(1000)

doQuit()
