#!/bin/sh
set -eux

_usage() {
  cat >&2 <<EOF
usage:
  mysites.sh build <site>
  mysites.sh publish <site>
EOF
  exit 64 # EX_USAGE
}

escape_html() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

# TODO add optional tags like changefreq
_generate_sitemap() {
  _last_updated="$(tail -1 "$1" | cut -f1)"
  sed \
    -e "s|%%LAST_UPDATED%%|${_last_updated}|g" \
    "${templates}/sitemap_meta.frag.xml"
  while IFS='	' read -r _date _gmi _title; do
    _path="${_gmi%.gmi}"
    sed \
      -e "s|%%DATE%%|${_date}|g" \
      -e "s|%%PATH%%|${_path}|g" \
      "${templates}/sitemap_entry.frag.xml"
  done < "$1"
  echo "</urlset>"
}

# $1 = path to index.gmi
_gmi_to_feed_tsv() {
  grep -E '=> \S* \d{4}-\d{2}-\d{2}' "$1" | \
    sed 's,=> \([^ ]*\) \([^ ]*\) - \(.*\),\2\t\1\t\3,g' | \
    sort -k1
}

# $1 = path to feed.tsv
_generate_atom_feed() {
  _last_updated="$(tail -1 "$1" | cut -f1)"
  sed \
    -e "s|%%LAST_UPDATED%%|${_last_updated}|g" \
    "${templates}/feed_meta.frag.xml"

  while IFS='	' read -r _date _gmi _title; do
    _path="${_gmi%.gmi}"
    sed \
      -e "s|%%DATE%%|${_date}|g" \
      -e "s|%%PATH%%|${_path}|g" \
      -e "s|%%TITLE%%|${_title}|g" \
      "${templates}/feed_entry.frag.xml"
    escape_html < "${htmlarticles}/${_path}.article.html"
    echo '</content></entry>'
  done < "$1"
  echo '</feed>'
}

_build() {
  rm -rf "${artifacts}"

  while IFS='	' read -r _date _gmi _title; do
    _dir="$(dirname "${_gmi}")"
    mkdir -p \
      "${builthtml}/${_dir}" \
      "${htmlarticles}/${_dir}"

    _article="${htmlarticles}/${_gmi%.gmi}.article.html"
    ./gmi2htmlarticle.awk < "${gmisrc}/${_gmi}" > "${_article}"

    _html="${builthtml}/${_gmi%.gmi}.html"
    sed \
      -e "s|%%TITLE%%|${_title}|g" \
      "${templates}/header.frag.html" > "${_html}"
    cat "${_article}" >> "${_html}"
    sed \
      -e "s|%%GMI%%|${_gmi}|g" \
      -e "s|%%DATE%%|${_date}|g" \
      "${templates}/footer.frag.html" >> "${_html}"
  done < "${publishedtsv}"

  _generate_sitemap "${publishedtsv}" > "${builthtml}/sitemap.xml"

  _gmi_to_feed_tsv "${gmisrc}/index.gmi" > "${artifacts}/feed.tsv"
  _generate_atom_feed "${artifacts}/feed.tsv" > "${builthtml}/feed.xml"
  # NOTE: the trailing slashes are used to copy directory contents
  cp -R "${assets}/" "${builthtml}/"

  _out="${artifacts}/out"
  mkdir -p "${_out}"
  tar -C "${gmisrc}" -cvzf "${_out}/gmi.tar.gz" .
  tar -C "${builthtml}" -cvzf "${_out}/html.tar.gz" .
  ls -alh "${_out}"
}

site="$2"
cache="${XDG_CACHE_HOME:-${HOME}/.cache}/mysites"

publishedtsv="sites/${site}/published.tsv"
gmisrc="sites/${site}/gmi"
templates="sites/${site}/templates"
assets="sites/${site}/assets"

artifacts="${cache}/${site}"
builthtml="${artifacts}/html"
htmlarticles="${artifacts}/htmlarticles"

#while getopts h: name
#do
#  case "${name}" in
#    h) target_hostname="${OPTARG}" ;;
#    ?)
#      echo "Usage: $0: [-h host] command" >&2
#      exit 64 # EX_USAGE
#      ;;
#    *) ;;
#  esac
#done
#shift $((OPTIND - 1))

case "$1" in
  build) _build ;;
  publish) _publish ;;
  *) echo "unknown command: '$1'" >&2; _usage ;;
esac
