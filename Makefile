clean: site
	./site clean

deploy: clean rebuild
	./site deploy

post:
	echo -e '---\ntitle: '${TITLE}'\nmain: '${PROJECT}'\n---\n\n' > projects/${PROJECT}/`date +%Y-%m-%d`-${TITLE}.markdown
	vim projects/${PROJECT}/`date +%Y-%m-%d`-${TITLE}.markdown

preview: rebuild
	./site watch

rebuild: site
	./site rebuild

site: site.hs
	ghc --make site.hs
