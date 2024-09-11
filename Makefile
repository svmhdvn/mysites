.POSIX:

all: sites/blog sites/empt

sites/blog:
	$(MAKE) -C sites/blog blog

sites/empt:
	$(MAKE) -C sites/empt empt
