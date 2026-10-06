#!/usr/bin/env sh
# Which model should judge? Judges the fixtures and the model scenarios under
# two judges, Haiku 4.5 and Sonnet 5.5, with every per-rule override removed,
# and prints where they disagree with the fixtures and with each other.
#
#   sh proof/judge-agreement.sh             # with the gateway session-start.sh started
#   sh proof/judge-agreement.sh --stub      # plumbing only; the stub ignores the model
set -u

cd "$(dirname "$0")/.." || exit 2
if [ -n "$(git status --porcelain -- src test)" ]; then
  echo "judge-agreement: src/ or test/ has uncommitted changes; commit or stash them first" >&2
  exit 2
fi
mkdir -p .verify
export BASE=${BASE:-main}
STUB_PID=""
if [ "${1:-}" = "--stub" ]; then
  export MARKER="// stub: fails standard"
  node proof/stub-judge.mjs >.verify/stub.log 2>&1 &
  STUB_PID=$!
  tries=0
  until grep -q listening .verify/stub.log 2>/dev/null || [ "$tries" -ge 20 ]; do tries=$((tries + 1)); sleep 0.25; done
  PROVIDER=stub
else
  export MARKER=""
  BIFROST_URL=${BIFROST_URL:-http://localhost:8080}
  if ! curl -fsS -m 2 -o /dev/null "$BIFROST_URL/health" 2>/dev/null; then
    echo "judge-agreement: no Bifrost gateway answers at $BIFROST_URL; set AWS_REGION and Bedrock credentials and run the SessionStart hook, or pass --stub" >&2
    exit 2
  fi
  PROVIDER=bifrost
fi

restore() { git checkout -q -- src test; git clean -fdq -- src test; }
cleanup() { restore; [ -n "$STUB_PID" ] && kill "$STUB_PID" 2>/dev/null; rm -rf .verify/judge-*.yaml .verify/cache-*; }
trap cleanup EXIT INT TERM
now_ms() {
  ns=$(date +%s%N 2>/dev/null)
  case $ns in *N*|"") echo "$(($(date +%s) * 1000))" ;; *) echo "$((ns / 1000000))" ;; esac
}

# A config per judge: the same rules, every per-rule llm override dropped,
# so each judge is asked every question.
python3 - "$PROVIDER" <<'PY'
import sys, yaml
provider = sys.argv[1]
config = yaml.safe_load(open("lawbook.yaml"))
for rule in config["rules"]:
    rule.pop("llm", None)
for name, model in [("haiku", "bedrock/anthropic.claude-haiku-4-5"), ("sonnet", "bedrock/anthropic.claude-sonnet-5-5")]:
    llm = {"provider": "bifrost", "model": model, "maxRequests": 200}
    if provider == "stub":
        llm = {"provider": "openai", "model": model, "baseUrl": "http://127.0.0.1:47391/v1", "maxRequests": 200}
    out = dict(config)
    out["llm"] = llm
    yaml.safe_dump(out, open(f".verify/judge-{name}.yaml", "w"), sort_keys=False, width=100)
PY

STANDARDS=$(python3 -c "import yaml; print(' '.join(r['id'] for r in yaml.safe_load(open('lawbook.yaml'))['rules'] if 'standard' in r))")

for judge in haiku sonnet; do
  cfg=".verify/judge-$judge.yaml"
  cache=".verify/cache-$judge"
  rm -rf "$cache"
  start=$(now_ms)
  lawbook test . --config "$cfg" --cache-dir "$cache" --format json >".verify/fixtures-$judge.json" 2>".verify/fixtures-$judge.err"
  echo "$(($(now_ms) - start))" >".verify/fixtures-$judge.ms"
  for scenario in proof/scenarios/model/*.sh; do
    restore
    number=$(basename "$scenario" | cut -d- -f1)
    # shellcheck disable=SC1090
    . "./$scenario"
    apply
    # shellcheck disable=SC2086
    lawbook check . --config "$cfg" --cache-dir "$cache" --only $STANDARDS --changed --since "$BASE" --format json \
      >".verify/scenario-$number-$judge.json" 2>/dev/null
    restore
  done
done

python3 - "$STANDARDS" <<'PY'
import json, glob, sys, os
standards = sys.argv[1].split()
def load(p):
    try: return json.load(open(p))
    except Exception: return None
fixtures = {j: load(f".verify/fixtures-{j}.json") for j in ("haiku", "sonnet")}
rows = []; failures = 0
# scenarios: which standard each one targets, and the file
import re
targets = {}
for p in sorted(glob.glob("proof/scenarios/model/*.sh")):
    n = os.path.basename(p).split("-")[0]
    text = open(p).read()
    rule = re.search(r'^rule="([^"]*)"', text, re.M).group(1)
    path = re.search(r'^file="([^"]*)"', text, re.M).group(1)
    targets[n] = (rule, path)
def fixture_cell(j, rule):
    rep = fixtures[j]
    if not rep: return "no run", 1
    for r in rep["rules"]:
        if r["id"] == rule:
            bad = [c for c in r["cases"] if c["expected"] != c["actual"]]
            return ("agrees" if not bad else "misses " + ", ".join(os.path.basename(c["path"]) for c in bad)), len(bad)
    return "-", 0
def scenario_cell(j, n, rule, path):
    rep = load(f".verify/scenario-{n}-{j}.json")
    if not rep: return "no run", 1
    for r in rep["results"]:
        if r["id"] == rule:
            for f in r.get("findings", []):
                if f.get("path") == path and f.get("decision"):
                    return f"warned, noul {f['decision']['noul']}", 0
            return f"passed ({r['status']})", 1
    return "-", 1
print("| Standard | Haiku on fixtures | Sonnet on fixtures | Scenario | Haiku on scenario | Sonnet on scenario |")
print("| --- | --- | --- | --- | --- | --- |")
for rule in standards:
    h, hb = fixture_cell("haiku", rule); s, sb = fixture_cell("sonnet", rule)
    sc = [(n, t) for n, t in targets.items() if t[0] == rule]
    if sc:
        n, (r, path) = sc[0]
        hs, hsb = scenario_cell("haiku", n, r, path); ss, ssb = scenario_cell("sonnet", n, r, path)
    else:
        n, hs, ss, hsb, ssb = "-", "-", "-", 0, 0
    failures += hb + sb + hsb + ssb
    print(f"| {rule} | {h} | {s} | {n} | {hs} | {ss} |")
# the clean scenario under both judges
clean = [n for n, t in targets.items() if t[0] == ""]
if clean:
    n = clean[0]
    cells = []
    for j in ("haiku", "sonnet"):
        rep = load(f".verify/scenario-{n}-{j}.json")
        warned = [r["id"] for r in rep["results"] if r["kind"] == "standard" and r["status"] != "pass"] if rep else ["no run"]
        failures += len(warned)
        cells.append("every standard passed" if not warned else "warned: " + ", ".join(warned))
    print(f"| clean change ({n}) | | | {n} | {cells[0]} | {cells[1]} |")
print()
for j in ("haiku", "sonnet"):
    rep = fixtures[j]
    usage = {"requests": 0, "cached": 0, "inputTokens": 0, "outputTokens": 0}
    for p in [f".verify/fixtures-{j}.json"] + glob.glob(f".verify/scenario-*-{j}.json"):
        r = load(p)
        u = (r or {}).get("summary", {}).get("usage") or {}
        for k in usage: usage[k] += u.get(k, 0)
    ms = open(f".verify/fixtures-{j}.ms").read().strip()
    print(f"{j}: {usage['requests']} request(s), {usage['cached']} cached, {usage['inputTokens']} tokens in, {usage['outputTokens']} out; fixtures took {ms} ms")
print()
print("judge-agreement: " + ("PASS, both judges agree with every fixture and every scenario" if failures == 0 else f"{failures} disagreement(s); see the table"))
sys.exit(1 if failures else 0)
PY
