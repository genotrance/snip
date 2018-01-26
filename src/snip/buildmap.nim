import tables
import terminal

import ./key
import ./keymap

var OUTPUT: seq[string] = @[]
var BKEYMAP = initTable[string, KEYS]()

var i = 0
echo "Press ESC for key-combos that don't get detected\n"
for en in KEYS.items():
    if en in @[CTRL_C, CTRL_Q, CTRL_S, CTRL_Z]:
        continue
    
    stdout.write "Enter " & $en & ": "

    let try1 = getKey()

    var add = ""
    if try1 == "27" and OUTPUT.len() != 0:
        add = "# " & $en & " = ?"
    else:
        add = $en & " = " & try1

    if BKEYMAP.hasKey(try1) and try1 != "27":
        add = "# " & add & " - duplicate of " & $BKEYMAP[try1]
    else:
        BKEYMAP[try1] = en

    OUTPUT.add(add)

    eraseLine()

    i += 1

for i in OUTPUT:
    echo i