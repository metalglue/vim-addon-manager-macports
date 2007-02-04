all: vim-addons.1
clean:
	rm -f vim-addons.1
vim-addons.1: vim-addons
	rd2 -r rd/rd2man-lib -o $(basename $@) $<
