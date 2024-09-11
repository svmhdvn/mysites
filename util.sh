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

# $1 = article
# $2 = nav_categories
article_to_html() {
    built_gmi="${1%.article}.gmi"
    published_gmi="published/${built_gmi#build/}"

    # shellcheck disable=SC2310
    last_updated_history="$(git_timestamps_human "${published_gmi}" || git_timestamps_human published)"
    last_updated="$(echo "${last_updated_history}" | head -1)"

    site_title="$(gmi_title < "${built_gmi}")"
    sed \
        -e "s|%%SITE_TITLE%%|${site_title}|g" \
        -e "s,%%NAV_TITLE%%,${NAV_TITLE},g" \
        -e "s|%%NAV_CATEGORIES%%|$2|g" \
        templates/header.html.in
    cat "$1"
    sed \
        -e "s|%%LAST_UPDATED%%|${last_updated}|g" \
        -e "s|%%GMI_URL%%|gemini://${DOMAIN}/${built_gmi#build/}|g" \
        templates/footer.html.in
}

# TODO add <priority> if needed
# $1 = categories
generate_sitemap() {
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
