_mina()
{
  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD-1]}
  case "$prev" in
    deploy|init|help)
      return 0
      ;;
  esac

  COMPREPLY=($(compgen -W "init deploy help" -- $cur))
}
complete -F _mina mina
