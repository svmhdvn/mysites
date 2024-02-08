#!/bin/sh

set -e

USERNAME=svmhdvn
FULLNAME="Siva Mahadevan"
DOMAIN="${USERNAME}.name"
EMAIL="me@${DOMAIN}"
tabchar='	'

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

gmi_feed_entries() {
    tsvdb="$1"
    category="$2"
    grep "${category}/" "$tsvdb" | while IFS="$tabchar" read -r created updated title f; do
        printf '=> /%s %s - %s\n' "$f" "$(echo "$created" | iso8601_date_only)" "$title"
    done
}

gmi_title() {
    sed -n '/^# /{s/# //p; q}'
}

# Build Tab-Separated Values (TSV) file containing all the posts (excluding
# front page content)
index_tsv() {
    find published -type f -name '*.gmi' ! -name 'index.gmi' | while IFS= read -r gmi; do
        git_history=$(git_timestamps_iso8601 "$gmi")
        created="$(echo "$git_history" | tail -1)"
        updated="$(echo "$git_history" | head -1)"
        printf '%s\t%s\t%s\t%s\n' \
            "$created" \
            "$updated" \
            "$(sed -n '/^# /{s/# //p; q}' "$gmi")" \
            "${gmi#published/}"
    done | sort -r
}

article_to_html() {
    article="$1"
    nav_categories="$2"

    built_gmi="${article%.article}.gmi"
    title="$(gmi_title < "$built_gmi")"
    published_gmi="published/${built_gmi#build/}"

    last_updated=$( (git_timestamps_human "$published_gmi" || git_timestamps_human published) | head -1)

    cat <<EOF
<!DOCTYPE html>
<html lang='en'>
  <head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <meta http-equiv='X-UA-Compatible' content='ie=edge'>
    <link rel='alternate' type='application/atom+xml' title='RSS/Atom Feed' href='/feed.xml'>
    <link rel='stylesheet' href='/style.css'>
    <title>${title}</title>
  </head>
  <body>
    <header>
      <nav>
        <strong><a href='/'>&lt;~${USERNAME}&gt;</a></strong>
        <ul>
          ${nav_categories}
        </ul>
      </nav>
      <h1>${title}</h1>
    </header>
    <main>
$(cat "$article")
    </main>
    <footer>
      <p>Last updated on ${last_updated}.</p>
      <p>Written and styled with 🥰 on a Pinebook Pro.</p>
      <p><a href="gemini://${DOMAIN}/${built_gmi#build/}">Best viewed using the Gemini protocol.</a></p>
      <p>☕ <a href="https://www.buymeacoffee.com/svmhdvn">Buy me a coffee</a></p>
    </footer>
  </body>
</html>
EOF

}

generate_atom_feed() {
    cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>${FULLNAME}</title>
  <id>tag:${DOMAIN},2024-02-01:default-atom-feed</id>
  <link href="https://${DOMAIN}/" />
  <link href="https://${DOMAIN}/feed.xml" rel="self" type="application/atom+xml" />
  <updated>$(git_timestamps_iso8601 . | head -1)</updated>
  <generator uri="https://git.sr.ht/~${USERNAME}/blog/tree/main/item/blog.sh">blog.sh</generator>
  <icon>https://${DOMAIN}/favicon.ico</icon>
  <logo>https://${DOMAIN}/siva.jpg</logo>
  <subtitle>${FULLNAME}'s Blog</subtitle>
  <author>
    <name>${FULLNAME}</name>
    <uri>https://${DOMAIN}/</uri>
    <email>${EMAIL}</email>
  </author>
EOF

    tsvdb="$1"
    while IFS="$tabchar" read -r created updated title gmi; do
        day=$(echo "$created" | iso8601_date_only)
        cat <<EOF
<entry>
  <title>${title}</title>
  <id>tag:${DOMAIN},${day}:${gmi%.gmi}.html</id>
  <link rel="alternate" href="https://${DOMAIN}/${gmi%.gmi}.html"/>
  <published>$created</published>
  <updated>$updated</updated>
  <content type="html">
$(escape_html < "build/${gmi%.gmi}.article")
  </content>
</entry>
EOF
    done < "$tsvdb"

    echo '</feed>'
}

# TODO add <priority> if needed
generate_sitemap() {
    categories="$1"

    cat <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<urlset xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"
    xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
<url>
  <loc>https://${DOMAIN}/</loc>
  <lastmod>$(git_timestamps_iso8601 published | head -1)</lastmod>
  <changefreq>weekly</changefreq>
</url>
EOF

    for category in $categories; do
        find "build/$category" -type f -name '*.html' | while IFS= read -r html; do
            gmipath="${html%.html}.gmi"
            cat <<EOF
<url>
  <loc>https://${DOMAIN}/${html#build/}</loc>
  <lastmod>$(git_timestamps_iso8601 "published/${gmipath#build/}" | head -1)</lastmod>
  <changefreq>weekly</changefreq>
</url>
EOF
        done
    done

    echo "</urlset>"
}

generate_front_page() {
    tsvdb="$1"

    cat <<EOF
# Siva Mahadevan

Hey :) Welcome to my blog!

## Directory

=> /me/ About Me
=> /posts/ Blog Posts
=> /recipes/ Vegetarian Recipes

## Feed

Here are some things I've written:

### Blog Posts

$(gmi_feed_entries "$tsvdb" "posts")

### Vegetarian Recipes

$(gmi_feed_entries "$tsvdb" "recipes")

## Contact

I'd love to hear your comments on my posts! You can comment publically by emailing my public inbox or privately at my personal email:

=> mailto:~${USERNAME}/public-inbox@lists.sr.ht Write a comment
=> https://lists.sr.ht/~${USERNAME}/public-inbox Public inbox archives
=> mailto:${EMAIL} Email me
EOF

}

package() {
    pubtype="$1"
    pubdest="package/$pubtype"

    find assets -type f | while IFS= read -r asset; do
        assetpath="$pubdest/${asset#assets/}"
        dirname "$assetpath" | xargs mkdir -p
        cp "$asset" "$assetpath"
    done

    find build -type f -name "*.$pubtype" | while IFS= read -r f; do
        destpath="$pubdest/${f#build/}"
        dirname "$destpath" | xargs mkdir -p
        cp "$f" "$destpath"
    done
}

case "$1" in
    index_tsv) index_tsv ;;
    article_to_html) article_to_html "$2" "$3" ;;
    generate_atom_feed) generate_atom_feed "$2" ;;
    generate_front_page) generate_front_page "$2" ;;
    generate_sitemap) generate_sitemap "$2" ;;
    package) package "$2" ;;
    *)
        echo "Unknown command: '$1'" >&2
        exit 1
esac
