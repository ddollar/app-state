https = require("https")
rest  = require("restler")
url   = require("url")

https.globalAgent.maxSockets = 5000

class Heroku

  constructor: (@key) ->

  get: (path, query={}, cb) ->
    if query instanceof Function
      cb = query
      query = {}
    options =
      hostname: "api.heroku.com"
      port: 443
      path: path
      query: query
      auth: ":#{@key}"
      headers:
        "User-Agent": "app-state/0.1"
    https.get options, (res) ->
      buffer = ""
      res.on "data", (data) -> buffer += data
      res.on "end",         -> cb null, JSON.parse(buffer)

exports.init = (key) ->
  new Heroku(key)
