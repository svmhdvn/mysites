.POSIX:
.SUFFIXES:

all: build

build:
	./blog.sh

publish:
	hut pages publish --domain svmhdvn.name --protocol GEMINI work/myblog.gmi.tar.gz
	hut pages publish --domain svmhdvn.name --protocol HTTPS work/myblog.html.tar.gz
