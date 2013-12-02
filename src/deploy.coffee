path         = require "path"
clc          = require "cli-color"
{spawn}      = require "child_process"
{BashScript} = require "./bash"

####
### Send commands to server ###
####
exports.deploy = (config) ->
  dir = config["server_dir"]

  # Open connection to server
  p = spawn "ssh", [config["server"], "bash -s"], stdio: ["pipe", 1, 2]

  # Write script directly to SSH's STDIN
  bs = new BashScript p.stdin

  # Initiate deployment
  bs.queue ->
    ### Write cleanup function ###
    @fun "cleanup", ->
      release_dir = path.join dir, "releases", "$rno"
      @if_zero "$rno", ->
        @cmd "rm", "-rf", release_dir

    ### Basic setup ###
    @log "Create subdirs"

    for subdir in ["shared", "releases", "tmp"]
      @mkdir dir, subdir

    # Create shared dirs
    @log "Create shared dirs"

    for shared_dir in config["shared_dirs"]
      @mkdir dir, "shared", shared_dir

    ### Fetch code ###
    @log "Fetch code"

    # Checkout repo
    @if_not_dir_exists "tmp/scm/.git", ->
      @cd dir, "tmp"
      @cmd "rm", "-rf", "scm"
      @cmd "git", "clone", "-b", config["branch"], config["repo"], "scm"

    # Update repo
    @cd dir, "tmp", "scm"
    @cmd "git", "checkout", config["branch"]
    @cmd "git", "pull"

    # Copy code to release dir
    @log "Copy code to release dir"
    # Compute version number
    @raw 'rno="$(readlink "' + (path.join dir, "current") + '")"'
    @raw 'rno="$(basename "$rno")"'
    @math "rno=$rno+1"
    @cmd "cp", "-r", (path.join dir, "tmp", "scm", config["prj_git_relative_dir"]), (path.join dir, "releases", "$rno")

    ### Link shared dirs ###
    @log "Link shared dirs"

    @cd dir, "releases", "$rno"
    for shared_dir in config["shared_dirs"]
      @mkdir (path.dirname shared_dir)
      @cmd "ln", "-s", (path.join dir, "shared", shared_dir), shared_dir

    ### Run pre-start scripts ###
    @log "Run pre-start scripts"
    for cmd in config["prerun"]
      @raw_cmd cmd

    ### Start the service ###
    @log "Start service"
    @raw_cmd config["run_cmd"]

    ### Update current link ###
    @log "Update current link"

    @cd dir
    @if_link_exists "current", ->
      @cmd "rm", "current"
    @cmd "ln", "-s", "releases/$rno", "current"

    ### Clean the release dir ###
    @log "Cleaning release dir"

    @cd dir, "releases"
    @assign_output "release_dirs",
      @build_find ".",
        maxdepth: 1
        mindepth: 1
        type: "d"
        printf: "%f\\n"

    @assign_output "num_dirs", 'echo "$release_dirs" | wc -l'
    @if_math "num_dirs > 10", ->
      @pipe (->
              @raw 'echo "$release_dirs" | sort -n | head -n1'),
            (->
              @while "read rm_dir", ->
                @cmd "rm", "-rf", "$rm_dir")
