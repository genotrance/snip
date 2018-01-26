import algorithm
import os
import ospaths
import osproc
import strutils
import tables
import threadpool
import times

import ./globals

var LASTRUN = epochTime()
var LASTBUFFER = ""
var TEMPDIR = ""

var KEYWORDS = initTable[string, seq[string]]()
var COMMENTS = initTable[string, seq[string]]()

MODES["nc"] = {
    "name": "Nim C",
    "codefile": "ctest.nim",
    "compile": "nim c",
    "execute": "./ctest",
    "language": "nim"
}.toTable()

MODES["ncp"] = {
    "name": "Nim CPP",
    "codefile": "cpptest.nim",
    "compile": "nim cpp",
    "execute": "./cpptest",
    "language": "nim"
}.toTable()

MODES["njc"] = {
    "name": "Nim ObjC",
    "codefile": "objctest.nim",
    "compile": "nim objc",
    "execute": "./objctest",
    "language": "nim"
}.toTable()

MODES["njs"] = {
    "name": "Nim JS",
    "codefile": "jstest.nim",
    "compile": "nim js -d:nodejs -o:jstest.js",
    "execute": "nodejs jstest.js",
    "language": "nim"
}.toTable()

MODES["py"] = {
    "name": "Python",
    "codefile": "test.py",
    "execute": "python",
    "language": "python"
}.toTable()

MODES["js"] = {
    "name": "NodeJS",
    "codefile": "test.js",
    "execute": "node",
    "language": "javascript"
}.toTable()

MODES["gcc"] = {
    "name": "C - gcc",
    "codefile": "test.c",
    "compile": "gcc -o test -Wall",
    "execute": "./test",
    "language": "c"
}.toTable()

MODES["g++"] = {
    "name": "C++ - g++",
    "codefile": "test.cpp",
    "compile": "g++ -o test -Wall",
    "execute": "./test",
    "language": "cpp"
}.toTable()

KEYWORDS["nim"] = @[
    "addr", "and", "as", "asm", "atomic",
    "bind", "block", "break",
    "case", "cast", "concept", "const", "continue", "converter",
    "defer", "discard", "distinct", "div", "do",
    "echo", "elif", "else", "end", "enum", "except", "export",
    "finally", "for", "from", "func",
    "generic",
    "if", "import", "in", "include", "interface", "is", "isnot", "iterator",
    "let",
    "macro", "method", "mixin", "mod",
    "nil", "not", "notin",
    "object", "of", "or", "out",
    "proc", "ptr",
    "raise", "ref", "return",
    "shl", "shr", "static",
    "template", "try", "tuple", "type",
    "using",
    "var",
    "when", "while", "with", "without",
    "xor",
    "yield"
]
KEYWORDS["python"] = @[
    "False", "None", "True", 
    "and", "as", "assert", 
    "break", 
    "class", "continue", 
    "def", "del", 
    "elif", "else", "except", 
    "finally", "for", "from", 
    "global", 
    "if", "import", "in", "is", 
    "lambda", 
    "nonlocal", "not", 
    "or", 
    "pass", 
    "raise", "return", 
    "try", 
    "while", "with", 
    "yield"
]
KEYWORDS["javascript"] = @[
    "abstract", "arguments", "await",
    "boolean", "break", "byte", 
    "case", "catch", "char", "class", "const", "continue",
    "debugger", "default", "delete", "do", "double", 
    "else", "enum", "eval", "export", "extends", 
    "false", "final", "finally", "float", "for", "function",
    "goto", 
    "if", "implements", "import", "in", "instanceof", "int", "interface",
    "let", "long", 
    "native", "new", "null", 
    "package", "private", "protected", "public", 
    "return", 
    "short", "static", "super", "switch", "synchronized", 
    "this", "throw", "throws", "transient", "true", "try", "typeof", 
    "var", "void", "volatile", 
    "while", "with", 
    "yield"
]
KEYWORDS["c"] = @[
    "auto", 
    "break", 
    "case", "char", "const", "continue", 
    "default", "do", "double", 
    "else", "enum", "extern", 
    "float", "for", 
    "goto", 
    "if", "inline", "int", 
    "long", 
    "register", "restrict", "return", 
    "short", "signed", "sizeof", "static", "struct", "switch", 
    "typedef", 
    "union", "unsigned", 
    "void", "volatile", 
    "while",

    "define", "defined", 
    "elif", "else", "endif", "error", 
    "if", "ifdef", "ifndef", "include", 
    "line", 
    "pragma", 
    "undef" 
]
KEYWORDS["cpp"] = @[
    "alignas", "alignof", "and", "and_eq", "asm", "atomic_cancel", "atomic_commit", "atomic_noexcept", "auto", 
    "bitand", "bitor", "bool", "break", 
    "case", "catch", "char", "char16_t", "char32_t", "class", "compl", "concept", "const", "constexpr", "const_cast", 
    "continue", "co_await", "co_return", "co_yield", 
    "decltype", "default", "delete", "do", "double", "dynamic_cast", 
    "else", "enum", "explicit", "export", "extern", 
    "false", "float", "for", "friend", 
    "goto", 
    "if", "import", "inline", "int", 
    "long", 
    "module", "mutable", 
    "namespace", "new", "noexcept", "not", "not_eq", "nullptr", 
    "operator", "or", "or_eq", 
    "private", "protected", "public", 
    "register", "reinterpret_cast", "requires", "return", 
    "short", "signed", "sizeof", "static", "static_assert", "static_cast", "struct", "switch", "synchronized", 
    "template", "this", "thread_local", "throw", "true", "try", "typedef", "typeid", "typename", 
    "union", "unsigned", "using", 
    "virtual", "void", "volatile", 
    "wchar_t", "while", 
    "xor", "xor_eq", 

    "override", "final", "transaction_safe", "transaction_safe_dynamic",

    "define", "defined", 
    "elif", "else", "endif", "error", 
    "if", "ifdef", "ifndef", "include", 
    "line", 
    "pragma", 
    "undef" 
]

COMMENTS["nim"] = @["#"]
COMMENTS["python"] = @["#"]
COMMENTS["js"] = @["//"]
COMMENTS["c"] = @["//"]
COMMENTS["cpp"] = @["//"]

template withDir*(dir: string; body: untyped): untyped =
    var curDir = getCurrentDir()
    try:
        setCurrentDir(dir)
        body
    finally:
        setCurrentDir(curDir)

proc setDir() =
    TEMPDIR = getTempDir() / "snip-" & $epochTime()
    if dirExists(TEMPDIR):
        sleep(1000)
        setDir()
        return

    createDir(TEMPDIR)

    if MODES[MODE]["language"] == "nim":
        let cd = getCurrentDir()
        withDir TEMPDIR:
            let f = open("nim.cfg", fmWrite)
            f.writeLine("path: \"" & cd.replace("\\", "/") & "\"")
            f.close()

proc run(buffer, tempdir: string, modeinfo: Table[string, string]) {.thread.} =
    var 
        codefile = ""
        compile = ""
        execute = ""

    if modeinfo.hasKey("codefile"):
        codefile = modeinfo["codefile"]
    else:
        return

    if modeinfo.hasKey("compile"):
        compile = modeinfo["compile"]
    if modeinfo.hasKey("execute"):
        execute = modeinfo["execute"]

    if compile == "":
        if execute == "":
            return
        compile = execute
        execute = ""

    withDir tempdir:
        let f = open(codefile, fmWrite)
        f.write(buffer)
        f.close()

        var (output, error) = execCmdEx(compile & " " & codefile)
        if error == 0 and execute != "":
            (output, error) = execCmdEx(execute)

        let o = open("out.txt", fmWrite)
        o.write(output)
        o.close()

proc compile*(foreground=false) =
    if TEMPDIR == "": setDir()

    let buffer = BUFFER.join("\n").strip()
    if buffer != LASTBUFFER and epochTime() - LASTRUN > 2.0:
        LASTRUN = epochTime()
        LASTBUFFER = buffer
        WOFFSET = 0
        if foreground:
            run(buffer, TEMPDIR, MODES[MODE])
        else:
            spawn run(buffer, TEMPDIR, MODES[MODE])

proc getOutput*(): string =
    result = ""
    if dirExists(TEMPDIR):
        withDir TEMPDIR:
            if fileExists("out.txt"):
                let f = open("out.txt")
                result = f.readAll()
                f.close()

proc cleanup*() =
    if TEMPDIR != "":
        try:
            removeDir(TEMPDIR)
        except:
            discard

proc isLanguage*(mode, token: string): bool =
    var table: Table[string, seq[string]]
    if mode == "keyword":
        table = KEYWORDS
    elif mode == "comment":
        table = COMMENTS
    if MODES.hasKey(MODE) and MODES[MODE].hasKey("language"):
        let lang = MODES[MODE]["language"]
        if table.hasKey(lang) and token in table[lang]:
            return true
    
    return false

proc setMode*(next=true) =
    var i = 0
    var allmodes: seq[string] = @[]
    for key in MODES.keys():
        if key == MODE:
            i = allmodes.len()
        allmodes.add(key)
    
    if next:
        i += 1
        if i == allmodes.len():
            i = 0
    else:
        i -= 1
        if i == -1:
            i = allmodes.len()-1

    MODE = allmodes[i]
