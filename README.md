```snip``` is text editor to speed up testing code snippets

```snip``` is a command line text editor that allows writing and testing short code snippets. It is not intended to be a replacement for traditional text editors or IDEs. Minimal text editing features are included along with options to make it easy to work with online gists and pastes.

__Installation__

```snip``` is built in [Nim](https://www.nim-lang.org) and can be obtained in various ways.

* Download the pre-built binary from the [Releases](https://github.com/genotrance/snip/releases) page
* Install via the Nimble package manager included with the [Nim](https://nim-lang.org/install.html) compiler

    ```
    nimble install https://github.com/genotrance/snip
    ```

Simply place the binary in the system PATH. If compiling locally, Nimble installs the binary in the ~/.nimble/bin directory which can be added to the system PATH.

__Features__

* Console text editor
* Supported on Windows, OSX and Linux, over SSH
* Support for various programming languages
* Basic syntax highlighting
* Output window showing results of compile / execution
* Load gist/snippet, create new gist
* Monitor file for changes and reload/recompile
* Custom key maps if desired

There is a long [TODO](TODO.txt) list since ```snip``` is still under heavy development.

__Usage__

```
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

    --nc                Nim C
    --ncp               Nim CPP
    --njc               Nim ObjC
    --njs               Nim JS
    --py                Python
    --js                NodeJS
    --gcc               C - gcc
    --g++               C++ - g++
```

__Key Mapping__

The default key mapping can be listed with the ```--map``` flag. If a different mapping is preferred, a ```keymap.txt``` file can be created in the same directory as the ```snip``` executable with a KEY = ACTION mapping. List of all available editor actions can be listed with the ```--act``` flag. A list of all special keys can be seen with the ```--key``` flag.

__Feedback__

```snip``` is a work in progress and any feedback or suggestions are welcome. It is hosted on [GitHub](https://github.com/genotrance/snip) with an MIT license so issues, forks and PRs are most appreciated.
