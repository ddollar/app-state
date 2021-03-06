async   = require("async")
coffee  = require("coffee-script")
express = require("express")
heroku  = require("./lib/heroku")
http    = require("http")
log     = require("./lib/logger").init("app-state")

http.globalAgent.maxSockets = 1000

delay = (ms, cb) -> setTimeout  cb, ms
every = (ms, cb) -> setInterval cb, ms

express.logger.format "method",     (req, res) -> req.method.toLowerCase()
express.logger.format "url",        (req, res) -> req.url.replace('"', "&quot")
express.logger.format "user-agent", (req, res) -> (req.headers["user-agent"] || "").replace('"', "")

app = express()

app.disable "x-powered-by"

app.use express.logger
  buffer: false
  format: "ns=\"app-state\" measure=\"http.:method\" source=\":url\" status=\":status\" elapsed=\":response-time\" from=\":remote-addr\" agent=\":user-agent\""
app.use express.cookieParser()
app.use express.bodyParser()
app.use express.basicAuth (user, pass, cb) -> cb(null, pass)
app.use app.router
app.use (err, req, res, next) -> res.send 500, error:(if err.message? then err.message else err)

app.get "/", (req, res) ->
  res.send "ok"

app.get "/apps/all/state", (req, res) ->
  headers = switch req.headers["x-heroku-sudo"]
    when "true" then { "X-Heroku-Sudo":"true", "X-Heroku-Sudo-User":req.headers["x-heroku-sudo-user"] }
    else {}
  api = heroku.init(req.user)
  api.get "/apps", headers:headers, (err, apps) ->
    return res.send(err, 403) if err
    async.parallel (apps.map (app) ->
      (cb) ->
        log.start "ps", app:app.name, (logger) ->
          api.get "/apps/#{app.name}/ps", headers:headers, (err, dynos) ->
            async.parallel
              app_name: (cb) -> cb(null, app.name)
              state: (cb) ->
                return cb(null, "sleeping") unless dynos
                return cb(null, "sleeping") if dynos.length is 0
                async.detect dynos,
                  (dyno, cb) ->
                    cb(dyno.state != "idle")
                  (awake) ->
                    if awake then cb(null, "awake") else cb(null, "sleeping")
              transitioned_at: (cb) ->
                return cb(null) if dynos.length is 0
                transitions = (dynos.map (dyno) -> dyno.transitioned_at).sort()
                cb null, transitions[transitions.length-1]
              (err, app) ->
                if err then logger.error(err) else logger.success()
                cb err, app),
    (err, state) ->
      return res.send(err, 403) if err
      res.send JSON.stringify(state)

app.listen (process.env.PORT or 5000)
