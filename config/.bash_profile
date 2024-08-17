alias pwd='printf "%q\n" "$(builtin pwd)"'
alias cdd='cd - > /dev/null'
alias ls='ls --color=auto'
alias ll='ls -alFG --color=always'
alias lt='ls -altr --color=always'
alias la='ls -A'
alias du0='du -xhd0 | sort -h'
alias du1='du -xhd1 | sort -h'
alias k='kubectl'
alias h='helm'
alias l='less'

# source Bash completion scripts
. /usr/share/bash-completion/bash_completion
for f in /usr/local/etc/bash_completion.d/*; do
  source $f
done

eval "$(register-python-argcomplete pipx)"
. <(pip3    completion --bash)
. <(pip     completion --bash)
. <(poetry  completions bash)
. <(node  --completion-bash)
. <(kubectl completion bash)
. <(helm    completion bash)
. <(yq      completion bash)

complete -o default -F __start_kubectl k
complete -o default -F __start_helm    h
complete -C /usr/local/bin/aws_completer aws
