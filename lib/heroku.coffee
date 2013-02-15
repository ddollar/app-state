https = require("https")
rest  = require("restler")
url   = require("url")

class Heroku

  constructor: (@key) ->

  get: (path, query={}, cb) ->
    if query instanceof Function
      cb = query
      query = {}
    options =
      query: query
      username: "none"
      password: @key
      headers:
        "User-Agent": "airbag/0.1"
    rest.get("https://api.heroku.com#{path}", options).on "complete", (data) ->
      if data instanceof Error
        cb data
      else if data and data.error
        cb data.error
      else
        cb null, data

exports.init = (key) ->
  new Heroku(key)
