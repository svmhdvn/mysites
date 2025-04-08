#!/bin/sh
set -eu

. ../../util.sh

FULLNAME='Siva Mahadevan'



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
