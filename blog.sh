#!/bin/sh
set -eu

git_timestamps_iso8601() {
    TZ=UTC0 git log --pretty='format:%ad' --date='format-local:%Y-%m-%dT%H:%M:%SZ' "$1"
}

git_timestamps_human() {
    TZ=UTC0 git log --pretty="format:%ad" --date='format-local:%F' "$1"
}

escape_html() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g' "$@"
}

iso8601_date_only() {
    sed 's/T.*//'
}

gmi_title() {
    sed -n '/^# /{s/# //p; q}' "$@"
}

gmi_feed_entries() {
    grep '^=>[[:blank:]]*[[:graph:]]*[[:blank:]]*[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' capsule/index.gmi | \
      cut -F2,3
}

html_feed_entries() {
  grep -e '<a .*>[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$@" | sed 's|^.*<a href=./\(.*\).>\([^ ]*\) - \(.*\)</a>.*|\2\t\1\t\3|'
}

generate_atom_feed() {
  entries="$(html_feed_entries "work/stage/index.html")"
  _last_updated="$(echo ${entries} | head -1 | cut -F1)"
  sed \
    -e "s|%%LAST_UPDATED%%|${_last_updated}|g" \
    templates/feed_meta.frag.xml

  while IFS='	' read -r date htmlpath title; do
    updated="$(git_timestamps_iso8601 "capsule/${htmlpath%.html}.gmi")"
    sed \
      -e "s|%%TITLE%%|${title}|g" \
      -e "s|%%URL%%|/${htmlpath}|g" \
      -e "s|%%PUBLISHED_DATE%%|${date}|g" \
      -e "s|%%UPDATED_DATE%%|${updated}|g" \
      templates/feed_entry.frag.xml
    escape_html "work/stage/${htmlpath}"
    echo '</content></entry>'
  done <<EOF
${entries}
EOF
  echo '</feed>'
}

# $1 = gmi
gmi_to_html() {
  site_title="$(gmi_title "$1")"
  sed \
    -e "s|%%TITLE%%|${site_title}|g" \
    templates/header.frag.html

  ./gmi2htmlarticle.awk "$1"

  updated="$(git_timestamps_human "$1")"
  sed \
    -e "s|%%UPDATED_DATE%%|${updated}|g" \
    -e "s|%%GMI%%|${1#capsule/}|g" \
    templates/footer.frag.html
}

mkdir -p work
rm -rf work/stage
cp -R capsule "work/stage"
cp assets/* "work/stage/"

find capsule -type f -name '*.gmi' | while IFS= read -r page; do
  gmi="${page#capsule/}"
  gmi_to_html "${page}" > "work/stage/${gmi%.gmi}.html"
  rm -f "work/stage/${gmi}"
done

generate_atom_feed > work/stage/feed.xml
tar -C work/stage -cvzf work/myblog.html.tar.gz .
