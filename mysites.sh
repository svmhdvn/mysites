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



# TODO add <priority> if needed
# $1 = categories
_generate_sitemap() {
    last_published="$(git_timestamps_iso8601 published | head -1)"

    cat <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<urlset xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"
    xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
<url>
  <loc>https://${DOMAIN}/</loc>
  <lastmod>${last_published}</lastmod>
  <changefreq>weekly</changefreq>
</url>
EOF

    for category in $1; do
        find "build/${category}" -type f -name '*.html' | while IFS= read -r html; do
            gmipath="${html%.html}.gmi"
            lastmod="$(git_timestamps_iso8601 "published/${gmipath#build/}" | head -1)"
            cat <<EOF
<url>
  <loc>https://${DOMAIN}/${html#build/}</loc>
  <lastmod>${lastmod}</lastmod>
  <changefreq>weekly</changefreq>
</url>
EOF
        done
    done

    echo "</urlset>"
}

# $1 = site
# $2 = gmi
# $3 = date
_article_to_html() {
  _gmisrc="sites/$1/gmi"
  _templates="sites/$1/templates"
  site_title="$(gmi_title < "${_gmisrc}/$2")"
  sed \
    -e "s|%%SITE_TITLE%%|${site_title}|g" \
    "${templates}/header.html.in"
  ./gmi2htmlarticle.awk < "${_gmisrc}/$2"
  sed \
    -e "s|%%WRITTEN_ON%%|$3|g" \
    -e "s|%%GMI_URL%%|gemini://${DOMAIN}/$2|g" \
    "${templates}/footer.html.in"
}

# $1 = path to feed.gmi
_generate_atom_feed() {
  _last_updated="$(tail -1 "$1" | cut -f1)"
  cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>${FULLNAME}</title>
  <id>tag:${DOMAIN},2024-02-01:default-atom-feed</id>
  <link href="https://${DOMAIN}/" />
  <link href="https://${DOMAIN}/feed.xml" rel="self" type="application/atom+xml" />
  <updated>${_last_updated}</updated>
  <generator uri="https://codeberg.org/svmhdvn/mysites">blog.sh</generator>
  <icon>https://${DOMAIN}/favicon.ico</icon>
  <logo>https://${DOMAIN}/siva.jpg</logo>
  <subtitle>${FULLNAME}'s Blog</subtitle>
  <author>
    <name>Siva Mahadevan</name>
    <uri>https://svmhdvn.name/</uri>
    <email>me@svmhdvn.name</email>
  </author>
EOF

  while IFS='	' read -r _date _path _title; do
    day=$(echo "${created}" | iso8601_date_only)
    escaped_html="$(escape_html < "build/${gmi%.gmi}.article")"
    cat <<EOF
<entry>
  <title>${title}</title>
  <id>tag:${DOMAIN},${day}:${gmi%.gmi}.html</id>
  <link rel="alternate" href="https://${DOMAIN}/${gmi%.gmi}.html"/>
  <published>${created}</published>
  <updated>${updated}</updated>
  <content type="html">
${escaped_html}
  </content>
</entry>
EOF
  done < "$1"
  echo '</feed>'
}
cache="${XDG_CACHE_HOME:-${HOME}/.cache}/mysites"
# $1 = site
_build() {
  _artifacts="${cache}/$1"
  _builtgmi="${_artifacts}/gmi"
  _builthtml="${_artifacts}/html"
  _out="${_artifacts}/out"

  while IFS='	' read -r _date _path _title; do
    _base="$(basename "${_path}")"
    _gmi="sites/$1/gmi/${_path}"
    mkdir -p "${_builtgmi}/${_base}" "${_builthtml}/${_base}"
    cp "${_gmi}" "${_builtgmi}/${_path}"
    _article_to_html "${_gmi}" > "${_builthtml}/${_path%.gmi}.html"
  done < "sites/$1/published.tsv"

  _generate_sitemap > "${_builthtml}/sitemap.xml"
  _generate_atom_feed > "${_builthtml}/atom.xml"

  grep -E '=> \S* \d{4}-\d{2}-\d{2}' "sites/$1/gmi/index.gmi" | \
    sed 's,=> \([^ ]*\) \([^ ]*\) - \(.*\),\2\t\1\t\3,g' | \
    sort -k1 > "${_artifacts}/feed.gmi"
  _generate_atom_feed "${_artifacts}/feed.gmi"

  mkdir -p "${_out}"

  ls -alh "${_out}"
}

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
  build) _build "$2" ;;
  publish) _publish "$2" ;;
  *) echo "unknown command: '$1'" >&2; _usage ;;
esac
