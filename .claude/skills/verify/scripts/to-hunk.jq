# Turns verify's two reports into Hunk comments.
#
#   jq -s --argjson t 5 --arg format session -f to-hunk.jq crap.json lawbook.json
#   jq -s --argjson t 5 --arg format sidecar -f to-hunk.jq crap.json lawbook.json
#
# Input is the slurped pair [poly-crap report, lawbook report]; either may be
# null. `session` emits the batch `hunk session comment apply --stdin` takes.
# `sidecar` emits the file `hunk diff --agent-context <file>` reads.

def pct: if . == null then "no" else "\(. | round)%" end;

def crap_comments:
  ((.[0] // {}).entries // [])
  | map(select(.score > $t))
  | map({
      filePath: .file,
      newLine: .start_line,
      summary: "CRAP \(.score) · CC \(.complexity) · \(.coverage | pct) coverage · \(.symbol)",
      rationale: "Complexity \(.complexity) with \(.coverage | pct) line coverage scores above \($t). Cover its branches with tests, or split it."
    });

def law_comments:
  ((.[1] // {}).results // [])
  | map(select(.status == "fail" or .status == "warn" or .status == "error"))
  | map(. as $rule
      | .findings[]
      | select(.path != null)
      | {
          filePath: .path,
          newLine: (.line // 1),
          summary: "[\($rule.id)] \(.message)\(if .decision then " (noul \(.decision.noul))" else "" end)",
          rationale: ($rule.description // "lawbook rule \($rule.id)") + " (level \($rule.level), \($rule.status))"
        });

(crap_comments + law_comments) as $comments
| if $format == "sidecar" then
    {
      version: 1,
      summary: "verify: \($comments | length) finding(s)",
      files: ($comments
        | group_by(.filePath)
        | map({
            path: .[0].filePath,
            annotations: map({ newRange: [.newLine, .newLine], summary, rationale, source: "verify" })
          }))
    }
  else
    { comments: ($comments | map({ filePath, newLine, summary })) }
  end
