.POSIX:

all: blog empt

blog:
	$(MAKE) -C sites/blog site

empt:
	$(MAKE) -C sites/empt site
