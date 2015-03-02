# Mina [![NPM version](https://badge.fury.io/js/mina.png)](http://badge.fury.io/js/mina) [![bitHound Score](https://www.bithound.io/CenturyUna/mina/badges/score.svg)](https://www.bithound.io/CenturyUna/mina) [![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/CenturyUna/mina?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

[![NPM](https://nodei.co/npm/mina.png?downloads=true)](https://nodei.co/npm/mina/)

A simple deploy tool inspired by [mina](http://nadarei.co/mina), based on [minco](https://github.com/dsmatter/minco). This project is powered by [node](http://nodejs.org), forcus on quick and lightweight deployment and server automation over ssh for [node](http://nodejs.org) projects.

## Latest Version
[v1.0.9](https://npmjs.org/package/mina)

## Installation
Make sure you have installed node.js including NPM

    sudo npm install -g mina

## Bash completion
Add this to your .bashrc, In this version only support bash

    eval "$(mina completion=bash)"

## Usage
    # Create an example deploy.json
    mina init

    # Adjust it to your needs in deploy.json
    {
        # Servers to deploy to
        "server": ["user@host1","user@host2"]
        # Port
        , "port": 13
        # Deploy to this dir on server
        , "server_dir": "/path/to/dir/on/server"
        # Git repository, only support git right now
        , "repo": "git@github.com:user/repo.git"
        # If you have more than one project in your git repo,
        # e.g. "projects/project_luna"
        , "prj_git_relative_dir": ""
        # Branch to be checkout and deploy
        , "branch": "master"
        # If remove git cloned directory then git clone again,
        # default is false
        , "force_regenerate_git_dir": false
        # Directories of your project in this array will use a
        # symbolic instead create every time when run deploy
        , "shared_dirs": ["node_modules", "db"]
        # How many release snapshots keep away from auto cleanup,
        # default is 10 if not presents
        , "history_releases_count": 10
        # Run customize scripts before run
        , "prerun": [
          "npm install",
          "npm test"
        ]
        # Start run your project
        , "run_cmd": "npm start"
    }

    # Deploy
    mina deploy

    # Or, indicate deploy config file
    MINA_CONFIG=deploy_scripts/to_dev.json mina deploy

## Keep in mind...

+ You have to ensure the username used for ssh have permission for operating directories
+ You have to ensure the remote server could execute `git clone`, that's means `git-core` must be installed, and, can clone the project from you git-repo.

## Contributors

+ [C.C.](https://github.com/fanweixiao)
+ Neal <neal.ma.sh@gmail.com>
+ Houjiazong <houjiazong@gmail.com>
+ BordenJardine <bordenjardine@gmail.com>
+ [Marcus Vorwaller](https://github.com/marcus)
+ [Allan Wind](https://github.com/allanwind)
