#!/bin/sh
set -eu

. ../../util.sh

# $1 = tsv DB
generate_front_page() {
    posts_feed_entries="$(gmi_feed_entries "$1" posts)"
    recipe_feed_entries="$(gmi_feed_entries "$1" recipes)"

    cat <<EOF
# EMPT

We provide on-premise managed IT services using 100% free and open source software. Our core product, "EMPT IT", comprises:
* Networking
* Data storage
* Email
* Instant messaging
* Single Sign On authentication
* Backups, replication, and monitoring

## EMPT IT

## Site Directory

=> /about/ About Us
=> /pricing/ Pricing
=> /news/ News
=> /help/ Help and Documentation
=> /faqs/ Frequently Asked Questions
EOF
}

case "$1" in
    index_tsv) index_tsv ;;
    article_to_html) article_to_html "$2" "$3" ;;
    generate_front_page) generate_front_page "$2" ;;
    generate_sitemap) generate_sitemap "$2" ;;
    package) package "$2" ;;
    *)
        echo "$0: ERROR: Unknown command: '$1'" >&2
        exit 64 # EX_USAGE
esac
