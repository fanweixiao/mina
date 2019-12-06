path         = require "path"
clc          = require "cli-color"
{spawn}      = require "child_process"
{BashScript} = require "./bash"

####
### Send commands to server ###
####

exports.deploy = (config) ->
  xtermColor = 13
  server = config["server"]
  if typeof server == "string"
    initDeploy server, config, clc.xterm(xtermColor).bold
  else if server instanceof Array
    for s in server
      initDeploy s, config, clc.xterm(xtermColor).bold
      xtermColor += 1

initDeploy = (server, config, color) ->
  dir = config["server_dir"]
  config["history_releases_count"] = 2 if config["history_releases_count"] && config["history_releases_count"] < 2
  # Open connection to server
  _srv_args = []
  _srv_args.push server
  _srv_args.push "-i #{config['identity_file']}" if config["identity_file"]
  _srv_args.push "-p #{config['port']}" if config["port"]
  _srv_args.push "bash -s"
  p = spawn "ssh", _srv_args, stdio: ["pipe", 1, 2]

  # Write script directly to SSH's STDIN
  bs = new BashScript p.stdin
  # Initiate deployment
  bs.queue ->
    ### Check deploy.lock ###
    @if_file_exists "#{dir}/deploy.lock", ->
      @log server + " A deployment is in process", color
      @cmd "echo", server, ' A deployment is in process'
      @cmd "exit 1"

    @touch dir, "deploy.lock"

    ### Write cleanup function ###
    @fun "cleanup", ->
      release_dir = path.join dir, "releases", "$rno"
      @if_zero "$rno", ->
        @cmd "rm", "-rf", release_dir

    ### Basic setup ###
    @log server + " Create subdirs", color

    for subdir in ["shared", "releases", "tmp"]
      @mkdir dir, subdir

    # Create shared dirs
    @log server + " Create shared dirs", color

    for shared_dir in config["shared_dirs"]
      @mkdir dir, "shared", shared_dir

    # Create shared files
    @log server + " Create shared files", color

    for shared_file in config["shared_files"]
      @touch dir, "shared", shared_file

    # Change to the dir before fetching code
    @cd dir

    ### Fetch code ###
    @log server + " Fetch code", color

    # Check if need remove all git dir first
    if config["force_regenerate_git_dir"]
      @cd dir, "tmp"
      @cmd "rm", "-rf", "scm"

    # Change dir to `dir` for more operations
    @cd dir

    # Checkout repo
    @if_not_dir_exists "tmp/scm/.git", ->
      @cd dir, "tmp"
      @cmd "rm", "-rf", "scm"
      @cmd "git", "clone", "-b", config["branch"], config["repo"], "scm"

    # Update repo
    @cd dir, "tmp", "scm"
    @cmd "git", "fetch"
    @cmd "git", "checkout", config["branch"]
    if config["reset_branch"]
      @cmd "git", "reset", "origin/#{config["branch"]}", "--hard"
    else
      @cmd "git", "rebase", "origin/#{config["branch"]}"

    # Build Project
    @log server + " Build projects", color
    @cd dir, "tmp", "scm", config["prj_git_relative_dir"]
    for cmd in config["build_cmd"]
      @raw_cmd cmd

    # Copy code to release dir
    @log server + " Copy code to release dir", color
    # Compute version number
    @raw 'rno="$(readlink "' + (path.join dir, "current") + '")"'
    @raw 'rno="$(basename "$rno")"'
    @math "rno=$rno+1"
    @cmd "cp", "--preserve=timestamps", "-r", (path.join dir, "tmp", "scm", config["prj_git_relative_dir"] || "", config["dist"] || ''), (path.join dir, "releases", "$rno")

    ### Link shared dirs ###
    @log server + " Link shared dirs"

    @cd dir, "releases", "$rno"
    for shared_dir in config["shared_dirs"]
      @mkdir (path.dirname shared_dir)
      @raw "[ -h #{shared_dir} ] && unlink #{shared_dir}"
      @cmd "ln", "-s", (path.join dir, "shared", shared_dir), shared_dir

    ### Link shared files ###
    @log server + " Link shared files"
    @cd dir, "releases", "$rno"
    for shared_file in config["shared_files"]
      @raw "[ -h #{shared_file} ] && unlink #{shared_file}"
      @cmd "ln -s", (path.join dir, "shared", shared_file), shared_file

    ### Run pre-start scripts ###
    @log server + " Run pre-start scripts", color
    for cmd in config["prerun"]
      @raw_cmd cmd

    ### Update current link ###
    @log server + " Update current link", color

    @cd dir
    @if_link_exists "current", ->
      @cmd "rm", "current"
    @cmd "ln", "-s", "releases/$rno", "current"

    ### Start the service ###
    @log server + " Start service", color
    @cmd "pwd"
    @cd "current"
    @raw_cmd config["run_cmd"]

    ### Clean the release dir ###
    @log server + " Cleaning release dir", color

    @cd dir, "releases"
    @assign_output "release_dirs",
      @build_find ".",
        maxdepth: 1
        mindepth: 1
        type: "d"
        printf: "%f\\n"

    @assign_output "num_dirs", 'echo "$release_dirs" | wc -l'
    @raw "dirs_num_to_keep=#{config["history_releases_count"] || 10}"
    @if_math "num_dirs > dirs_num_to_keep", ->
      @pipe (->
              @math "dirs_num_to_remove=$num_dirs-$dirs_num_to_keep"
              @raw 'echo "$release_dirs" | sort -n | head -n$dirs_num_to_remove'),
            (->
              @while "read rm_dir", ->
                @cmd "rm", "-rf", "$rm_dir")

    ### Remove deploy.lock ###
    @cd dir
    @cmd "rm", "-rf", "deploy.lock"
