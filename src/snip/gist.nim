import os
import httpclient
import strutils
import uri

import ./globals

var CLIENT: HttpClient

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

proc getGist*(url: string): string =
    if CLIENT == nil:
        CLIENT = newHttpClient(proxy = getProxy())

    var parsed = url.parseUri()
    if parsed.hostname == "gist.github.com":
        parsed.hostname = "gist.githubusercontent.com"
        parsed.path &= "/raw"
    elif parsed.hostname == "pastebin.com":
        if not ("raw" in parsed.path):
            parsed.path = "/raw" & parsed.path
    elif parsed.hostname == "play.nim-lang.org":
        parsed.hostname = "gist.githubusercontent.com"
        parsed.path = "/anonymous/" & parsed.query.split("=")[1] & "/raw"
        parsed.query = ""

    if parsed.hostname in @["github.com", "www.github.com"]:
        parsed.path = parsed.path.replace("/blob/", "/raw/")

    if DEBUG:
        echo $parsed
        discard stdin.readLine()

    return CLIENT.getContent($parsed)