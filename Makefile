.PHONY:build build-ui build-backend help

build: build-ui build-backend


build-ui:
	corepack enable
	pnpm --dir UI install --frozen-lockfile
	pnpm --dir UI build

build-backend:
	export CGO_ENABLED=1;export CGO_LDFLAGS=-static;go build -o ./casa main.go;upx --lzma --best casa

help:
	@echo "call john"
