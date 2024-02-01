.POSIX:
.SUFFIXES:
.SUFFIXES: .article .html .gmi

USERNAME = svmhdvn
PUBLISHED_POSTS != find published -type f -name '*.gmi'
BUILT_POSTS != find published -type f -name '*.gmi' | sed 's,^published/,build/,g'
ASSETS != find assets -type f
NAV_CATEGORIES != find published -mindepth 1 -maxdepth 1 -type d | sed 's%published/\(.*\)%<li><a href="/\1/">\1</a></li>%g'

all: package/gmi.tar.gz package/html.tar.gz

package/gmi.tar.gz: package/gmi
	tar -C "$<" -cvzf "$@" .

package/html.tar.gz: package/html
	tar -C "$<" -cvzf "$@" .

package/gmi: build/.started build/index.gmi $(ASSETS)
	./blog.sh package gmi

build/.started: $(PUBLISHED_POSTS) blog.sh gmi2htmlarticle.awk
	rm -rf build
	cp -R published build
	touch "$@"

build/index.gmi: build/posts.tsv
	./blog.sh generate_front_page "$<" > "$@"

package/html: build/.started build/index.html build/sitemap.xml build/feed.xml $(BUILT_POSTS:.gmi=.html) $(ASSETS)
	./blog.sh package html
	cp build/*.xml package/html

build/feed.xml: build/posts.tsv $(BUILT_POSTS:.gmi=.article)
	./blog.sh generate_atom_feed "$<" > "$@"

build/sitemap.xml: build/index.html $(BUILT_POSTS:.gmi=.html)
	./blog.sh generate_sitemap > "$@"

build/posts.tsv: $(PUBLISHED_POSTS)
	./blog.sh index_tsv > "$@"

.gmi.article:
	./gmi2htmlarticle.awk "$<" > "$@"

.article.html:
	./blog.sh article_to_html "$<" "$(NAV_CATEGORIES)" > "$@"

publish: publish_gmi publish_html

publish_gmi: package/gmi.tar.gz
	hut pages publish --domain "$(USERNAME).name" --protocol GEMINI "$<"

publish_html: package/html.tar.gz
	hut pages publish --domain "$(USERNAME).name" --protocol HTTPS "$<"

clean:
	xargs rm -rf < .gitignore
