#!/bin/sh
set -eu

git_timestamps_iso8601() {
    TZ=UTC0 git log --pretty='format:%ad' --date='format-local:%Y-%m-%dT%H:%M:%SZ' "$1"
}

git_timestamps_human() {
    TZ=UTC0 git log --pretty="format:%ad" --date='format-local:%F at %R UTC' "$1"
}

escape_html() {
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g' "$@"
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

# $1 = category
gmi_feed_entries() {
    grep "$1/" published.tsv | while IFS='	' read -r created updated title f; do
        created_date="$(echo "${created}" | iso8601_date_only)"
        echo "=> /${f} ${created_date} - ${title}"
    done
}

# $1 = article
article_to_html() {
    built_gmi="${1%.article}.gmi"
    published_gmi="published/${built_gmi#build/}"

    # shellcheck disable=SC2310
    last_updated_history="$(git_timestamps_human "${published_gmi}" || git_timestamps_human published)"
    last_updated="$(echo "${last_updated_history}" | head -1)"

    site_title="$(gmi_title < "${built_gmi}")"
    sed \
        -e "s|%%TITLE%%|${site_title}|g" \
        templates/header.frag.html
    cat "$1"
    sed \
        -e "s|%%LAST_UPDATED%%|${last_updated}|g" \
        -e "s|%%GMI_URL%%|gemini://svmhdvn.name/${built_gmi#build/}|g" \
        templates/footer.frag.html
}

# TODO add <priority> if needed
generate_sitemap() {
    last_published="$(git_timestamps_iso8601 published | head -1)"

    sed \
        -e "s|%%LAST_UPDATED%%|${last_published}|g" \
        templates/sitemap_meta.frag.xml

    for category in posts thoughts notes about; do
        find "build/${category}" -type f -name '*.html' | while IFS= read -r html; do
            gmipath="${html%.html}.gmi"
            lastmod="$(git_timestamps_iso8601 "published/${gmipath#build/}" | head -1)"
            sed \
                -e "s|%%DATE%%|${lastmod}|g" \
                templates/sitemap_entry.frag.xml
        done
    done

    echo "</urlset>"
}

generate_atom_feed() {
  _last_updated="$(tail -1 published.tsv | cut -f1)"
  sed \
    -e "s|%%LAST_UPDATED%%|${_last_updated}|g" \
    templates/feed_meta.frag.xml

  while IFS='	' read -r _date _gmi _title; do
    _path="${_gmi%.gmi}"
    sed \
      -e "s|%%DATE%%|${_date}|g" \
      -e "s|%%PATH%%|${_path}|g" \
      -e "s|%%TITLE%%|${_title}|g" \
      templates/feed_entry.frag.xml
    escape_html "${htmlarticles}/${_path}.article.html"
    echo '</content></entry>'
  done < published.tsv
  echo '</feed>'
}

generate_front_page() {
    cat <<EOF
# Siva Mahadevan

Hey :) Welcome to my blog!

## Directory

=> /me/ About Me
=> /posts/ Archive

## Feed

EOF

    gmi_feed_entries posts

    cat <<EOF

## Contact

I'd love to hear your comments on my posts! You can comment publically by emailing my public inbox or privately at my personal email:

=> mailto:~svmhdvn/public-inbox@lists.sr.ht Write a comment
=> https://lists.sr.ht/~svmhdvn/public-inbox Public inbox archives
=> mailto:me@svmhdvn.name Email me
EOF

}

cmd="$1"
shift
case "${cmd}" in
    index_tsv) index_tsv ;;
    article_to_html) article_to_html "$@" ;;
    generate_atom_feed) generate_atom_feed ;;
    generate_front_page) generate_front_page ;;
    generate_sitemap) generate_sitemap "$@" ;;
    package) package "$@" ;;
    *)
        echo "$0: ERROR: Unknown command: '${cmd}'" >&2
        exit 64 # EX_USAGE
esac
