import algorithm
import os
import ospaths
import osproc
import pegs
import strutils
import tables
import threadpool
import times

import ./gist
import ./globals

# Channels for compiler
var CCODE*: Channel[tuple[mode, buffer: string]]
var COUT*: Channel[string]
CCODE.open(0)
COUT.open(0)

var TEMPDIR = ""

var KEYWORDS = initTable[string, seq[string]]()
var COMMENTS = initTable[string, seq[string]]()
var ERRORS = initTable[string, string]()

MODES["nc"] = {
    "name": "Nim C",
    "codefile": "ctest.nim",
    "compile": "nim c",
    "execute": "./ctest",
    "language": "nim"
}.toTable()

MODES["ns"] = {
    "name": "Nim Script",
    "codefile": "nimstest.nims",
    "execute": "nim e",
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

ERRORS["nim"] = """[$#]+\({\d+}[\,][ ]\d+\)[ .]+"""
ERRORS["python"] = """[File ]+["][$#]+["][\, line]+{\d+}"""
ERRORS["c"] = """[$#]+[:]{\d+}[:]{\d+}[:][ error]"""
ERRORS["cpp"] = """[$#]+[:]{\d+}[:]{\d+}[:][ error]"""

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

proc run(buffer, tempdir: string, modeinfo: Table[string, string]): string =
    result = ""
    var
        codefile = ""
        compile = ""
        execute = ""
        error = 0

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

        try:
            (result, error) = execCmdEx(compile & " " & codefile)
            if error == 0 and execute != "":
                try:
                    (result, error) = execCmdEx(execute)
                except OSError:
                    result = "Failed to execute"
        except OSError:
            result = "Failed to compile"

proc compile*() =
    if BUFFER != LASTBUFFER:
        WOUTPUT = @[""]
        WOFFSET = 0
        if not CCODE.trySend((mode: MODE, buffer: BUFFER.join("\n"))):
            echo "Failed to send code for compilation"

proc startCompiler(tempdir: string, modes: OrderedTable[string, Table[string, string]]) {.thread.} =
    var ready: bool
    var mode, code: string
    var data: tuple[mode, buffer: string]

    while true:
        code = ""
        while true:
            # Get last buffer
            (ready, data) = CCODE.tryRecv()
            if ready:
                code = data.buffer
                mode = data.mode
            else:
                break
            sleep(100)

        if code != "":
            if not COUT.trySend(run(code, tempdir, modes[mode])):
                echo "Failed to send execution output for display"

        sleep(100)

proc setupCompiler*() =
    if TEMPDIR == "": setDir()

    spawn startCompiler(TEMPDIR, MODES)

proc getErrorInfo() =
    ERRORINFO = (-1, -1)
    if ERRORS.hasKey(MODES[MODE]["language"]) and WOUTPUT.len() != 0:
        var i = 0
        #var fn = FILENAME.extractFilename()
        #if fn == "" or isUrl(fn):
        #    fn = MODES[MODE]["codefile"]
        for line in WOUTPUT:
            if line =~ peg(ERRORS[MODES[MODE]["language"]] % MODES[MODE]["codefile"]):
                ERRORINFO = (matches[0].parseInt()-1, i)
                break
            i += 1

proc getOutput*(): bool =
    result = false
    var ready: bool
    var buffer: string
    while true:
        # Get last output
        (ready, buffer) = COUT.tryRecv()
        if ready:
            WOUTPUT = buffer.strip().splitLines()
            result = true
        else:
            break
    if result:
        getErrorInfo()

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
