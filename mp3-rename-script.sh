#!/usr/bin/env bash
set -uo pipefail          # removed “‑e”
shopt -s nullglob

# 0=quiet 1=normal 2=very‑verbose
LOG_LEVEL=1
log()   { [[ $LOG_LEVEL -ge 1 ]] && printf '%s\n' "$*"; }
logvv() { [[ $LOG_LEVEL -ge 2 ]] && printf '%s\n' "$*"; }

while getopts ":qv" opt; do
  case $opt in
    q) LOG_LEVEL=0 ;; v) ((LOG_LEVEL++)) ;;
    *) printf 'Usage: %s [-q] [-v]\n' "$0" >&2; exit 1 ;;
  esac
done
shift $((OPTIND-1))

unique_name() {
  local stem=$1 n=1
  while [[ -e "${stem}.mp3" ]]; do stem="${1}-${n}"; ((n++)); done
  printf '%s\n' "$stem"
}

for f in *.mp3; do
  log "► $f"

  # try to get tit2 tag
  title=$(
    { id3v2 -l "$f" 2>/dev/null || true; } |
    sed -n 's/^TIT2.*: \(.*\)$/\1/p' | head -n1
  )

  # try to via ffprobe
  [[ -z $title ]] && title=$(
    { ffprobe -v quiet -show_entries format_tags=title \
              -of default=nk=1:nw=1 "$f" || true; }
  )


  if [[ -z $title ]]; then
    log "  • No title tag – skipping"
    continue
  fi

  logvv "  • Raw: $title"

  # check that new filename is safe
  safe=$(printf '%s' "$title" |
         tr -d '\r' |
         tr '/\000' '_' |
         tr -c 'A-Za-z0-9._ -' '_' |
         sed 's/[[:space:]]\+/_/g')
  stem=$(unique_name "$safe")
  target="${stem}.mp3"
  logvv "  • Target: $target"

  # rename the file
  mv -n -- "$f" "$target"
  log "  • Renamed → $target"
done
