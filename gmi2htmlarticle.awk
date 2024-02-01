#!/usr/bin/awk -f

BEGIN {
    print "<article>"
}

/```/ {
    if (preformatted_mode) {
        printf("</code></pre>")
    } else {
        printf("<pre><code>")
        preformatted_alttext = $2
    }
    preformatted_mode = !preformatted_mode
    next
}

{
    if (preformatted_mode) {
        print
        next
    }
}

function handle_list_mode() {
    if (list_mode) {
        print "    </ul>"
        list_mode = 0
    }
}

function handle_sections(num) {
    for (i = num; i <= 3; ++i) {
        if (in_section[i]) {
            print "  </section>"
            in_section[i] = 0
        }
    }
}

function trim_line_type() {
    $1 = ""

    # weird awk thing to trim leading space
    $0 = $0
    $1 = $1
}

/^=>/ {
    handle_list_mode()
    trim_line_type()
    href = $1
    alt_text = substr($0, index($0, $2))

    if (href ~ /\.(jpg|png|avif)$/) {
        printf("    <p><img src='%s' alt='%s'></p>\n", href, alt_text)
    } else {
        # Preserve links to other gemini capsules
        if (href ~ /.gmi$/ && href !~ /^gemini:\/\//) {
            sub(".gmi", ".html", href)
        }
        printf("    <p><a href='%s'>%s</a></p>\n", href, alt_text)
    }
    next
}

/^>/ {
    handle_list_mode()
    trim_line_type()
    printf("    <blockquote>%s</blockquote>\n", $0)
    next
}

/^# / {
    # handled by publish.sh for proper semantic handling of <section> headers
    next;
}

/^###? / {
    handle_list_mode()
    header_num = length($1)
    trim_line_type()
    handle_sections(header_num)
    print "  <section>"
    printf("    <h%d>%s</h%d>\n", header_num, $0, header_num)
    in_section[header_num] = 1
    next
}

/^\*/ {
    trim_line_type()

    if (!list_mode) {
        print "    <ul>"
        list_mode = 1
    }
    printf("      <li>%s</li>\n", $0)
    next
}

/[^[:space:]]/ {
    handle_list_mode()
    printf("    <p>%s</p>\n", $0)
}

END {
    handle_list_mode()
    handle_sections()
    print "</article>"
}
