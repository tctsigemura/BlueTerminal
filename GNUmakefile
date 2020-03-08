SUBDIRS:=src bin

all:
	$(foreach dir, $(SUBDIRS), $(MAKE) --directory=$(dir); )

install: all
	$(foreach dir, $(SUBDIRS), $(MAKE) --directory=$(dir) install; )

