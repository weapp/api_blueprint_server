rfr = require 'rfr'

aglio = require 'aglio'

cache = rfr 'lib/cache'
client = rfr 'lib/github_client'
settings = rfr 'lib/settings'

render_in = (res, cache_key) ->
  (err, file) ->
    if err?
      res.send "Error: #{err['message']}"
    else unless file['content']?
      res.send "Not found"
    else
      blueprint = new Buffer(file['content'], 'base64').toString('utf8')
      aglio.render blueprint, 'default', (err, html, warnings) ->
        if err?
          console.log "Error rendering: #{err}"
        else
          cache.set cache_key, html
          res.send html

exports.index = (req, res) ->
  dir = req.param('dir')
  dir = if dir? then "#{dir}/" else ''

  path = "#{dir}#{req.params.file_name}"
  branch = req.param('branch')

  sha = req.param('sha')

  info = settings.repo_info(branch, path)

  cache_key = if sha? then "#{info.ref}-#{path}-#{sha}" else "#{info.ref}-#{path}"

  cached = cache.get(cache_key)[cache_key]

  if cached
    console.log "Serving cached path '#{cache_key}'"
    res.send cached
  else
    console.log "Updating cache for path '#{cache_key}'"
    if sha?
      blob_info = {
        user: info.user
        repo: info.repo
        sha: sha
      }

      client.gitdata.getBlob blob_info, render_in(res)
    else
      client.repos.getContent info, render_in(res, cache_key)
