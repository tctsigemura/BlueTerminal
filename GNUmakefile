SUBDIRS:=src bin

all:
	$(foreach dir, $(SUBDIRS), $(MAKE) --directory=$(dir); )

install :
	$(foreach dir, $(SUBDIRS), $(MAKE) --directory=$(dir) install; )

clean :
	$(foreach dir, $(SUBDIRS), $(MAKE) --directory=$(dir) clean; )
