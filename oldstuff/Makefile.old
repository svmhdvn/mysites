.POSIX:
.SUFFIXES:
.SUFFIXES: .article .html .gmi

PUBLISHED_PAGES != find published -type f -name '*.gmi'
BUILT_PAGES != find published -type f -name '*.gmi' | sed 's,^published/,build/,g'
ASSETS != find assets -type f

all: package/gmi.tar.gz package/html.tar.gz

package/html.tar.gz: build/sitemap.xml build/feed.xml $(ASSETS)
	./blog.sh package html
	cp build/*.xml package/html
	tar -C package/html -cvzf '$@' .

package/gmi.tar.gz: build/index.gmi $(ASSETS)
	./blog.sh package gmi
	tar -C package/gmi -cvzf '$@' .

build/sitemap.xml: build/index.html $(BUILT_PAGES:.gmi=.html)
	./blog.sh generate_sitemap > '$@'

build/index.gmi: blog.sh published.tsv
	./blog.sh generate_front_page > '$@'

build/feed.xml: $(BUILT_PAGES:.gmi=.article)
	./blog.sh generate_atom_feed > '$@'

build/.started: $(PUBLISHED_PAGES) blog.sh gmi2htmlarticle.awk
	rm -rf build
	cp -R published build
	touch '$@'

.PHONY built_pages: $(PUBLISHED_PAGES)
	rm -rf build
	cp -R published build

.article.html:
	./blog.sh article_to_html '$<' > '$@'

.gmi.article:
	./gmi2htmlarticle.awk '$<' > '$@'

publish: publish_gmi publish_html

publish_gmi: package/gmi.tar.gz
	hut pages publish --domain svmhdvn.name --protocol GEMINI '$<'

publish_html: package/html.tar.gz
	hut pages publish --domain svmhdvn.name --protocol HTTPS '$<'

clean:
	xargs rm -rf < .gitignore
