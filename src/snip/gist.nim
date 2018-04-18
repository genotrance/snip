import os
import httpcore
import httpclient
import json
import strutils
import tables
import uri

import ./compile
import ./globals

proc getProxy*(): Proxy =
    ## Returns ``nil`` if no proxy is specified.
    var url = ""
    try:
      if existsEnv("http_proxy"):
        url = getEnv("http_proxy")
      elif existsEnv("https_proxy"):
        url = getEnv("https_proxy")
    except ValueError:
        return nil

    if url.len > 0:
      var parsed = parseUri(url)
      if parsed.scheme.len == 0 or parsed.hostname.len == 0:
        parsed = parseUri("http://" & url)
      let auth =
        if parsed.username.len > 0: parsed.username & ":" & parsed.password
        else: ""
      return newProxy($parsed, auth)
    else:
      return nil

proc isUrl*(url: string): bool =
    result = false
    if "http://" == url.substr(0, 6) or "https://" == url.substr(0, 7):
        result = true

proc adjustUrl(url: string): string =
    var parsed = url.parseUri()
    if parsed.hostname == "gist.github.com":
        parsed.hostname = "gist.githubusercontent.com"
        if parsed.path.split("/").len() == 2:
            parsed.path = "/anonymous" & parsed.path
        parsed.path &= "/raw"
    elif "pastebin.com" in parsed.hostname:
        if "raw" notin parsed.path:
            parsed.path = "/raw" & parsed.path
    elif parsed.hostname == "play.nim-lang.org":
        parsed.hostname = "gist.githubusercontent.com"
        parsed.path = "/anonymous/" & parsed.query.split("=")[1] & "/raw"
        parsed.query = ""
    elif "dpaste.de" in parsed.hostname or "ghostbin.com" in parsed.hostname:
        if "raw" notin parsed.path:
            parsed.path &= "/raw"

    if parsed.hostname in @["github.com", "www.github.com"]:
        parsed.path = parsed.path.replace("/blob/", "/raw/")

    return $parsed

proc getGist*(url: string): string =
    result = ""
    var client = newHttpClient(proxy = getProxy())

    try:
        let r = client.get(adjustUrl(url))
        if r.code().is2xx():
            result = r.body
    except OSError:
        discard

proc createGist*(): string =
    result = ""
    var client = newHttpClient(proxy = getProxy())
    var url = "http://ix.io"
    var data = "name:1=" & MODES[MODE]["codefile"] & "&f:1=" & BUFFER.join("\n")
    try:
        let r = client.post(url, data)
        if r.code() == Http200:
            result = r.body.strip()
            log("Created gist: " & result)
        else:
            log("Create gist failed: " & r.status & "\n" & r.body)
    except OSError:
        discard
