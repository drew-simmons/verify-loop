# The factory's repo-owned contract: the only stack-specific lines in the loop.
# Stages 1 and 3 of the gate come from here; everything else is the plugin's.
BASE=origin/main
THRESHOLD=5
SOURCE_GLOBS='src/**/*.js'
TEST_GLOBS='test/**/*.test.js'
COVERAGE_FILE=lcov.info
syntax() { for f in "$@"; do node --check "$f" || return 1; done; }
test_with_coverage() { npm run -s coverage; }
TRACKER=github
HUNK=1
NON_CODE='.factory/** *.md docs/** proof/compare/results/**'
COMMIT_TRAILERS=''
