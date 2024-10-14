alias pwd='printf "%q\n" "$(builtin pwd)"'
alias cdd='cd - > /dev/null'
alias ls='ls --color=auto'
alias ll='ls -alFG --color=always'
alias lt='ls -altr --color=always'
alias la='ls -A'
alias du0='du -xhd0 | sort -h'
alias du1='du -xhd1 | sort -h'
alias l='less'

alias  k='kubectl'
alias kg='kubectl-grep'
alias ar='kubectl-argo-rollouts'
alias  a='argocd'
alias  h='helm'

# source Bash completion scripts
. /usr/share/bash-completion/bash_completion
for f in /usr/local/etc/bash_completion.d/*; do
  source $f
done

eval "$(register-python-argcomplete pipx)"
. <(pip3                  completion --bash)
. <(pip                   completion --bash)
. <(poetry                completions bash)
. <(just                --completions bash)
. <(node                --completion-bash)
. <(kubectl               completion bash)
. <(kubectl-grep          completion bash)
. <(kubectl-argo-rollouts completion bash)
. <(argocd                completion bash)
. <(helm                  completion bash)
. <(yq                    completion bash)

# register completion for aliases as well
complete -o default -F __start_kubectl k
complete -o default -F __start_kubectl-grep          kg
complete -o default -F __start_kubectl-argo-rollouts ar
complete -o default -F __start_argocd  a
complete -o default -F __start_helm    h
complete -C /usr/local/bin/aws_completer aws
