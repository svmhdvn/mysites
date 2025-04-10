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

git_timestamps_iso8601() {
    TZ=UTC0 git log --pretty='format:%ad' --date='format-local:%Y-%m-%dT%H:%M:%SZ' "$1"
}

git_timestamps_human() {
    TZ=UTC0 git log --pretty="format:%ad" --date='format-local:%F at %R UTC' "$1"
}

escape_html() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

iso8601_date_only() {
    sed 's/T.*//'
}

# $1 = pubtype
package() {
    find assets -type f | while IFS= read -r asset; do
        assetpath="package/$1/${asset#assets/}"
        dirname "${assetpath}" | xargs mkdir -p
        cp "${asset}" "${assetpath}"
    done

    find build -type f -name "*.$1" | while IFS= read -r f; do
        destpath="package/$1/${f#build/}"
        dirname "${destpath}" | xargs mkdir -p
        cp "${f}" "${destpath}"
    done
}

gmi_title() {
    sed -n '/^# /{s/# //p; q}'
}

# Build Tab-Separated Values (TSV) file containing all the posts (excluding
# front page content)
index_tsv() {
    find published -type f -name '*.gmi' ! -name 'index.gmi' | while IFS= read -r gmi; do
        git_history=$(git_timestamps_iso8601 "${gmi}")
        created="$(echo "${git_history}" | tail -1)"
        updated="$(echo "${git_history}" | head -1)"
        gmi_title="$(sed -n '/^# /{s/# //p; q}' "${gmi}")"
        printf '%s\t%s\t%s\t%s\n' \
            "${created}" \
            "${updated}" \
            "${gmi_title}" \
            "${gmi#published/}"
    done | sort -r
}

# $1 = tsvdb
# $2 = category
gmi_feed_entries() {
    grep "$2/" "$1" | while IFS='	' read -r created updated title f; do
        created_date="$(echo "${created}" | iso8601_date_only)"
        echo "=> /${f} ${created_date} - ${title}"
    done
}

# TODO add <changefreq> to published.tsv
# $1 = path to published.tsv
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

# $1 = site
# $2 = gmi
# $3 = date
_article_to_html() {
  _gmisrc="sites/$1/gmi"
  site_title="$(gmi_title < "${_gmisrc}/$2")"
  sed \
    -e "s|%%SITE_TITLE%%|${site_title}|g" \
    "${templates}/header.frag.html"
  ./gmi2htmlarticle.awk < "${_gmisrc}/$2"
  sed \
    -e "s|%%GMI_URL%%|$2|g" \
    -e "s|%%WRITTEN_ON%%|$3|g" \
    "${templates}/footer.frag.html"
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
    escape_html < "build/${_path}.article"
    echo '</content></entry>'
  done < "$1"
  echo '</feed>'
}
cache="${XDG_CACHE_HOME:-${HOME}/.cache}/mysites"
_build() {
  _artifacts="${cache}/${site}"

  _builtgmi="${_artifacts}/gmi"
  _builthtml="${_artifacts}/html"
  while IFS='	' read -r _date _gmi _title; do
    _base="$(basename "${_gmi}")"
    _gmifullpath="sites/${site}/gmi/${_gmi}"
    mkdir -p "${_builtgmi}/${_base}" "${_builthtml}/${_base}"
    cp "${_gmifullpath}" "${_builtgmi}/${_gmi}"
    _article_to_html "${_gmifullpath}" > "${_builthtml}/${_gmi%.gmi}.html"
  done < "sites/${site}/published.tsv"

  _generate_sitemap "sites/${site}/published.tsv" > "${_builthtml}/sitemap.xml"

  _gmi_to_feed_tsv "sites/${site}/gmi/index.gmi" > "${_artifacts}/feed.tsv"
  _generate_atom_feed "${_artifacts}/feed.tsv" > "${_builthtml}/feed.xml"

  _out="${_artifacts}/out"
  mkdir -p "${_out}"
  tar -C "${_builtgmi}" -cvzf "${_out}/gmi.tar.gz" .
  tar -C "${_builthtml}" -cvzf "${_out}/html.tar.gz" .
  ls -alh "${_out}"
}

site="$2"
templates="sites/${site}/templates"

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
