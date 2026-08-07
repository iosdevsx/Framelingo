#!/bin/sh

set -eu

ruby Scripts/architecture/test-package-graph.rb
ruby Scripts/architecture/test-architecture-policy.rb
ruby Scripts/audit-module-boundaries.rb --self-test
ruby Scripts/audit-module-boundaries.rb "$@"
