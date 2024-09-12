#!/bin/sh
set -eu

. ../../util.sh

FULLNAME='Siva Mahadevan'

# $1 = tsvdb
generate_atom_feed() {
    last_updated="$(git_timestamps_iso8601 . | head -1)"
    cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>${FULLNAME}</title>
  <id>tag:${DOMAIN},2024-02-01:default-atom-feed</id>
  <link href="https://${DOMAIN}/" />
  <link href="https://${DOMAIN}/feed.xml" rel="self" type="application/atom+xml" />
  <updated>${last_updated}</updated>
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

    while IFS='	' read -r created updated title gmi; do
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

# $1 = tsv DB
generate_front_page() {
    posts_feed_entries="$(gmi_feed_entries "$1" posts)"
    recipe_feed_entries="$(gmi_feed_entries "$1" recipes)"

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

${posts_feed_entries}

### Vegetarian Recipes

${recipe_feed_entries}

## Contact

I'd love to hear your comments on my posts! You can comment publically by emailing my public inbox or privately at my personal email:

=> mailto:~${USERNAME}/public-inbox@lists.sr.ht Write a comment
=> https://lists.sr.ht/~${USERNAME}/public-inbox Public inbox archives
=> mailto:${EMAIL} Email me
EOF

}

case "$1" in
    index_tsv) index_tsv ;;
    article_to_html) article_to_html "$2" "$3" ;;
    generate_atom_feed) generate_atom_feed "$2" ;;
    generate_front_page) generate_front_page "$2" ;;
    generate_sitemap) generate_sitemap "$2" ;;
    package) package "$2" ;;
    *)
        echo "$0: ERROR: Unknown command: '$1'" >&2
        exit 64 # EX_USAGE
esac
