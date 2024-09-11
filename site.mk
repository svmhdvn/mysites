.SUFFIXES:
.SUFFIXES: .article .html .gmi

PUBLISHED_POSTS != find published -type f -name '*.gmi'
BUILT_POSTS != find published -type f -name '*.gmi' | sed 's,^published/,build/,g'
ASSETS != find assets -type f

NAV_CATEGORIES != echo $(CATEGORIES) | sed 's% *\([^ ]\{1,\}\)%<li><a href="/\1/">/\1</a></li>%g'
BLOGSH = USERNAME='$(USERNAME)' FULLNAME='$(FULLNAME)' DOMAIN='$(DOMAIN)' EMAIL='$(EMAIL)' NAV_TITLE='$(NAV_TITLE)' ./blog.sh

build/.started: $(PUBLISHED_POSTS) blog.sh ../../gmi2htmlarticle.awk
	rm -rf build
	cp -R published build
	touch '$@'

package/gmi.tar.gz: package/gmi
	tar -C '$<' -cvzf '$@' .

package/html.tar.gz: package/html
	tar -C '$<' -cvzf '$@' .

build/posts.tsv: build/.started
	$(BLOGSH) index_tsv > '$@'

package/gmi: build/.started build/index.gmi $(ASSETS)
	$(BLOGSH) package gmi

package/html: build/.started build/index.html build/sitemap.xml $(BUILT_POSTS:.gmi=.html) $(ASSETS)
	$(BLOGSH) package html
	cp build/*.xml package/html

build/index.gmi: build/posts.tsv
	$(BLOGSH) generate_front_page '$<' > '$@'

build/sitemap.xml: build/index.html $(BUILT_POSTS:.gmi=.html)
	$(BLOGSH) generate_sitemap '$(CATEGORIES)' > '$@'

build/feed.xml: build/posts.tsv $(BUILT_POSTS:.gmi=.article)
	$(BLOGSH) generate_atom_feed '$<' > '$@'

.article.html:
	$(BLOGSH) article_to_html '$<' '$(NAV_CATEGORIES)' > '$@'

.gmi.article:
	../../gmi2htmlarticle.awk '$<' > '$@'

publish: publish_gmi publish_html

publish_gmi: package/gmi.tar.gz
	hut pages publish --domain $(DOMAIN) --protocol GEMINI '$<'

publish_html: package/html.tar.gz
	hut pages publish --domain $(DOMAIN) --protocol HTTPS '$<'

clean:
	xargs rm -rf < ../../.gitignore
