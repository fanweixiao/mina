clc  = require "cli-color"
path = require "path"

### Facilities to iteratively construct a bash script ###

class BashScript
  constructor: (stream) ->
    @stream = stream

  queue: (queue_f) ->
    queue_f.call this
    @stream.end()

  raw: (raw) ->
    @stream.write raw + "\n"

  shebang: ->
    @raw "#!/bin/bash"

  echo: (text) ->
    @raw "echo " + (enclose_quotes text)

  log: (desc, cf=clc.white.bold) ->
    @echo (cf "----> " + desc)

  log_cmd: (cmd...) ->
    @log (cmd.join " "), clc.white

  if: (cond, then_queuer, else_queuer) ->
    @raw "if #{cond}; then"
    then_queuer.call this
    if else_queuer?
      @raw "else"
      else_queuer.call this
    @raw "fi"

  if_test: (cond, then_queuer, else_queuer) ->
    @if "[[ " + cond + " ]]", then_queuer, else_queuer

  if_math: (cond, then_queuer, else_queuer) ->
    @if "(( " + cond + " ))", then_queuer, else_queuer

  if_cmd_successful: (then_queuer, else_queuer) ->
    @if_num_equal "$?", "0", then_queuer, else_queuer

  while: (cond, body_queuer) ->
    @raw "while #{cond}; do"
    body_queuer.call this
    @raw "done"

  fun: (name, body_queuer) ->
    @raw "function " + name + " {"
    body_queuer.call this
    @raw "}"

  pipe: (left_queuer, right_queuer) ->
    @raw "("
    left_queuer.call this
    @raw ") | ("
    right_queuer.call this
    @raw ")"

  cmd: (cmd, args...) ->
    @log_cmd cmd, args...
    @raw cmd + " " + (quote_args args)
    @error_check()

  cd: (dir_components...) ->
    @cmd "cd", (path.join dir_components...)

  mkdir: (dir_components...) ->
    @cmd "mkdir", "-p", (path.join dir_components...)

  math: (expr) ->
    @raw "(( " + expr + " ))"

  assign: (variable, val) ->
    if typeof val == "function"
      @stream.write "#{variable}=\""
      val.call this
      @stream.write "\""
    else
      @raw "#{variable}=\"#{val}\""

  assign_output: (variable, cmd, args...)->
    if typeof cmd == "function"
      val = =>
        @stream.write "$("
        cmd.call this
        @stream.write ")"
    else
      val = "$(#{cmd} #{quote_args args})"

    @assign variable, val

  find: (dir, options) ->
    @raw_cmd (build_find dir, options)

  raw_cmd: (cmd) ->
    @log_cmd cmd
    @raw cmd
    @error_check()

  error_check: ->
    @if_cmd_successful \
      (->
        @log "ok", clc.green),
      (->
        @log "Command failed with code $?", clc.red
        @raw "cleanup; exit 1")

  build_find: (dir, options) ->
    args = [dir]
    for opt, val of options
      args.push "-#{opt}"
      args.push val if val
    "find " + (quote_args args)


unary_if_tests =
  exists: "-e"
  file_exists: "-f"
  dir_exists: "-d"
  link_exists: "-h"
  pipe_exists: "-p"
  readable: "-r"
  writable: "-w"
  block_file_exists: "-b"
  char_file_exists: "-c"
  zero: "-z"
  nonzero: "-n"

binary_if_tests =
  equal: "="
  not_equal: "!="
  less: "<"
  greater: ">"
  num_equal: "-eq"
  num_not_equal: "-ne"
  num_less: "-lt"
  num_greater: "-gt"
  num_less_equal: "-le"
  num_greater_equal: "-ge"

# Inject the if functions
for name, symbol of unary_if_tests
  ((name, symbol) ->
    BashScript.prototype["if_#{name}"] = (cond, then_queuer, else_queuer) ->
      @if_test "#{symbol} #{cond}", then_queuer, else_queuer
    BashScript.prototype["if_not_#{name}"] = (cond, then_queuer, else_queuer) ->
      @if_test "! #{symbol} #{cond}", then_queuer, else_queuer
  )(name, symbol)

for name, symbol of binary_if_tests
  ((name, symbol) ->
    BashScript.prototype["if_#{name}"] = (op1, op2, then_queuer, else_queuer) ->
      @if_test "#{op1} #{symbol} #{op2}", then_queuer, else_queuer
  )(name, symbol)

enclose_quotes  = (text) ->
  '"' + (text.toString().replace /"/g, '"') + '"'

quote_args = (args) ->
  (args.map enclose_quotes).join " "

exports.BashScript = BashScript
