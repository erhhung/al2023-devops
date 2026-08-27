# shellcheck disable=SC2148 # Tips depend on target shell

# strip binaries in the given directories, overwriting
# the original only if the stripped version is smaller
#
#   usage: strip_bins <dir1> [dir2]...
# example: strip_bins /usr/local/bin
#
strip_bins() {
  local dir path target temp stage old_size new_size links
  local -A seen=()

  for dir; do
    [[ -d $dir ]] || {
      printf >&2 '[%s] not a directory: %s\n' "${FUNCNAME[0]}" "$dir"
      return 2
    }

    while IFS= read -r -d '' path; do
      target=$(realpath -e -- "$path") || continue
      # only process each dereferenced target once
      [[ -f $target && -x $target && \
          ! ${seen[$target]+set} ]] || continue
      seen["$target"]=1

      # don't strip shell/coreutils
      # executables or ELF loaders
      case $target in
        /usr/bin/bash|/bin/bash|\
        /usr/bin/coreutils|/bin/coreutils|\
        /lib*/ld-musl-*|/usr/lib*/ld-musl-*|\
        /lib*/ld-linux-*|/usr/lib*/ld-linux-*)
          continue
          ;;
      esac

      # avoid breaking hard-links by replacing inode
      links=$(stat -c '%h' -- "$target") || return 1
      if (( links > 1 )); then
        printf >&2 'skipping hard-linked file: %s\n' "$target"
        continue
      fi

      # only strip ELF binaries,
      # not scripts/other types
      file -Lb -- "$target" | grep -q '^ELF ' || continue

      # /tmp should be tmpfs mount, so no image
      # layer write occurs for the trial output
      temp=$(mktemp "${TMPDIR:-/tmp}/${FUNCNAME[0]}.XXXXXXXX") || return 1

      strip --strip-all -o "$temp" -- "$target" || {
        printf >&2 '[%s] stripping failed: %s\n' "${FUNCNAME[0]}" "$target"
        rm -f -- "$temp"
        return 1
      }

      old_size=$(stat -c '%s' -- "$target") || {
        rm -f -- "$temp"
        return 1
      }
      new_size=$(stat -c '%s' -- "$temp") || {
        rm -f -- "$temp"
        return 1
      }
      # don't touch target if already stripped
      (( new_size < old_size )) || {
        rm -f -- "$temp"
        continue
      }

      # atomic rename requires the staging
      # file to share target's filesystem
      stage="$target.${temp#*.}"

      # retain target metadata and extended
      # attributes before atomic replacement
      cp --preserve=mode,ownership,timestamps,xattr -- "$temp" "$stage" || {
        printf >&2 '[%s] staging failed: %s\n' "${FUNCNAME[0]}" "$target"
        rm -f -- "$temp" "$stage"
        return 1
      }
      rm -f -- "$temp"

      # replace target atomically
      mv -f -- "$stage" "$target" || {
        printf >&2 '[%s] replacing failed: %s\n' "${FUNCNAME[0]}" "$target"
        rm -f -- "$stage"
        return 1
      }

      printf 'stripped: %s (%d -> %d bytes)\n' \
        "$target" "$old_size" "$new_size"
    done < <(
      find "$dir" \( -type f -o -type l \) -print0
    )
  done
}
