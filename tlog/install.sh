#!/bin/sh
set -e
go install ./cmd/tlog
go install ./cmd/taglog
echo "installed tlog and taglog to $(go env GOPATH)/bin"
