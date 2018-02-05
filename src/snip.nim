import os
import sequtils
import strutils
import tables

import snip/actions
import snip/compile
import snip/globals
import snip/key
import snip/keymap
import snip/ui
import snip/undo

const HELP = """
snip $#
Text editor to speed up testing code snippets

Usage: snip [file|url]

URLs:
    https://gist.github.com/usr/hash
    https://pastebin.com/hash
    https://play.nim-lang.org/?gist=hash

Flags:
    --mon               Monitor file and load changes
    --map               Show keymap
    --act               List all editor actions
    --key               List all key definitions
""" % VERSION

proc help() =
    echo HELP
    
    for mode in MODES.keys():
        echo "    --" & mode & "\t\t" & MODES[mode]["name"]

proc parseCli() =
    let params = commandLineParams()
    for param in params:
        if param == "--debug":
            DEBUG = true
        elif param in @["-h", "--help", "-?", "/?", "/h"]:
            help()
            quit()
        elif param == "--map":
            echo "KEY MAP:"
            echo getKeyHelp()
            quit()
        elif param == "--act":
            echo "ACTIONS:"
            for en in ACTIONS.items():
                echo "  " & $en
            quit()
        elif param == "--key":
            echo "KEYS:"
            for en in KEYS.items():
                echo "  " & $en
            quit()
        elif param.replace("--", "") in toSeq(MODES.keys):
            MODE = param.replace("--", "")
        elif param == "--mon":
            MONITOR = true
        else:
            doLoad(param, build=false)

proc init() =
    clearScreen()
    loadMaps()
    loadActions()
    parseCli()
    setupCompiler()
    setupKey()
    compile()
    redraw()

init()
while true:
    backup()
    handleKey()
    doReload()
    compile()
    sleep(10)
    writeOutput()
