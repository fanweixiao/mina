fs = require "fs"

mandatory_keys = [
  "server",
  "server_dir",
  "repo",
  "run_cmd"
]

default_options =
  shared_dirs: [],
  branch     : "master",
  prerun     : []

exports.parse = (path) ->
  raw = fs.readFileSync path, "UTF-8"
  config = JSON.parse raw

  # Check mandatory keys
  for key in mandatory_keys
    throw new Error "Missing option: " + key unless config[key]?

  # Set defaults
  for key of default_options
    config[key] ?= default_options[key]

  config
