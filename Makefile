.PHONY: server dev

server:
	python -m SimpleHTTPServer

dev:
	# npm -g install coffee-script
	# TODO figure out proper way to combine multiple files
	coffee --watch --bare --output lib/ --compile src/

setup-ghpages:
	rm -Rf _deploy
	mkdir _deploy
	cd _deploy && git init && git remote add origin git@github.com:lucaspiller/1gam-january.git && git checkout -b gh-pages

publish: setup-ghpages
	rm -Rf _deploy/*
	cp -R lib _deploy
	cp -R media _deploy
	cp -R vendor _deploy
	cp style.css _deploy
	cp index.html _deploy
	cd _deploy && git add . && git add -u . && git commit -m "Updated `date`" && git push origin gh-pages --force
