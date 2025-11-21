# shellcheck disable=SC2148 # Tips depend on target shell
# shellcheck disable=SC1090 # Can't follow non-const source
# shellcheck disable=SC1091 # Not following: not input file
# shellcheck disable=SC2086 # Double quote prevent globbing
# shellcheck disable=SC2206 # Quote to avoid word splitting
# shellcheck disable=SC2207 # Prefer mapfile to split output

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
alias ap='ansible-playbook'
alias tf='terraform'
alias  a='argocd'
alias  h='helm'

alias ip='ip -c=auto'
alias arp='arp -a'

# source Bash completion scripts
. /usr/share/bash-completion/bash_completion
for f in /usr/local/etc/bash_completion.d/*; do
  . "$f"
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
. <(kind                  completion bash)
. <(vcluster              completion bash)
#. <(yq                   completion bash)

complete -o dirnames -f -X '!*.*json'       jq
complete -o dirnames -f -X '!*.@(yaml|yml)' yq
complete -C /usr/local/bin/aws_completer    aws

# register completion for aliases as well
complete -o default -F __start_kubectl k
complete -o default -F __start_kubectl-grep          kg
complete -o default -F __start_kubectl-argo-rollouts ar
complete -o default -F __start_argocd  a
complete -o default -F __start_helm    h

# check TCP port connectivity
# usage: port <port> [host]
# default host is localhost
port() {
  [ "$1" ] || {
    cat <<EOT

Check TCP port connectivity
Usage: port <port> [host]
Default host is localhost

EOT
    return 0
  }
  local port=$1 host=${2:-localhost}
  if [ "${port-0}" -eq "${port-1}" ] 2> /dev/null; then
    nc -zv -w1 "$host"  "$port" 2>&1 | \
      head -n2 | tail -n1  | colrm 1 6
  else
    echo >&2 "Invalid port!"
    return 1
  fi
}

# show details of certificate chain from
# stdin, PEM file, website or K8s secret
cert() {
  local stdin host port args
  if [ -p /dev/stdin ]; then
    stdin=$(cat)
  else
    [ "$1" ] || {
      cat <<EOT

Show details of certificate chain from
stdin, PEM file, website or K8s secret

Usage: cert [file | host=. [port=443]]
       cert -k [namespace/]<tls-secret>
All args ignored if stdin is available

cert < website.pem       # standard input
cert   website.pem       # local PEM file
cert   website.com       # website.com:443
cert   website.com:8443  # website.com:8443
cert   8443              # localhost:8443
cert   .                 # localhost:443
cert -k namespace/secret # K8s "tls.crt"
EOT
      echo; return 0
    }
    # certs from K8s secret
    if [ "$1" == -k ]; then
      local secret=$2
      [[ "$secret" == */* ]] && {
        args+=(-n ${secret%/*})
        secret=${secret#*/}
      }
      stdin=$(kubectl get secret $secret "${args[@]}" \
        -o jsonpath='{ .data.tls\.crt }' | base64 -d)
    else
      host=${1:-localhost}
      [ "$host" == . ] && host=localhost
      # strip scheme & path if is an URL
      host=${host#*://}; host=${host%%/*}
      port=${2:-443}

      # handle host:port syntax
      [[ "$host" == *:* ]] && {
        port=${host#*:}
        host=${host%%:*}
      }
      # handle if only port number given
      if [ "${host-0}" -eq "${host-1}" ] 2> /dev/null; then
        port=$host
        host=localhost
      fi
      # use proxy for s_client if needed
      [ "$http_proxy" ] && args+=(-proxy
        $(cut -d/ -f3- <<< "$http_proxy")
      )
    fi
  fi

  local cert="" line out
  while read -r line; do
    # concatenate lines in each cert block
    # until ";" delimiter from awk command
    if [ "$line" == ';' ]; then
      out=$(openssl x509 -text -inform pem -noout <<< "$cert")
      [ "$out" ] && echo -e "\n$out"
      cert=""
    else
      cert+="$line"$'\n'
    fi
  done < <(
    if [ "$stdin" ]; then
      # certs from stdin
      echo "$stdin"
    elif [ -f "$host" ]; then
      # certs from file
      cat "$host"
    else
      # certs from host
      args=(
        s_client "${args[@]}"
        -connect "$host:$port"
        -showcerts
      )
      openssl "${args[@]}" <<< ""
    fi 2> /dev/null | \
      awk '
      /-----BEGIN CERTIFICATE-----/,
        /-----END CERTIFICATE-----/
      ' | \
      awk 'BEGIN {
        cert=""
        }
        /-----BEGIN CERTIFICATE-----/ {
          cert=$0
          next
        }
        /-----END CERTIFICATE-----/ {
          # output ";" as delimiter
          # between each cert block
          cert=cert"\n"$0"\n;"
          print cert
          cert=""
          next
        } {
          cert=cert"\n"$0
        }'
  )
  [ "$out" ] && echo
}
