.PHONY: js

all: js

dir:
	mkdir -p js

js: dir
	toaster -d -c
