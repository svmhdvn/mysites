.POSIX:
.SUFFIXES:

all: build

build:
	./blog.sh

lint:
	shellcheck -o all blog.sh

publish: lint
	hut pages publish --domain svmhdvn.name --protocol GEMINI work/myblog.gmi.tar.gz
	hut pages publish --domain svmhdvn.name --protocol HTTPS work/myblog.html.tar.gz
