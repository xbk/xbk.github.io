.PHONY: run init mocked requirements
run:
	@jekyll serve --safe

mocked:
	@jekyll serve --safe --config "./_config.yml,./_mocked.yml"

init: bower_components vendor

bower_components:
	@bower install

vendor:
	@bower-installer

requirements:
	@for p in npm jekyll bower bower-installer ; do \
		command -v $$p || echo "[WARN] \"$$p\" is not installed";  \
	done
