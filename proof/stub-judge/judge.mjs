// The judge behind ./claude, so the loop's model stage can be exercised with
// no credentials. lawbook's `claude-code` provider runs `claude -p
// --output-format json --json-schema <answer> ...` with the files on stdin
// and reads the result envelope from stdout. This one decides
// deterministically: a request fails the standard when a file carries the
// marker comment or is a fail fixture.
//
//   PATH="$PWD/proof/stub-judge:$PATH" lawbook check . --config lawbook.stub.yaml
import { readFileSync } from "node:fs";

export const MARKER = "// stub: fails standard";

/** noul 0.1 for a marked file or a fail fixture, 0.9 otherwise. */
function judge(text) {
  if (text.includes(MARKER)) {
    return { noul: 0.1, reason: `A file carries the marker "${MARKER}".` };
  }
  if (/^File: \S*\/fail\.js$/m.test(text)) {
    return { noul: 0.1, reason: "The file is a fail fixture." };
  }
  return { noul: 0.9, reason: "No file carries the stub marker and none is a fail fixture." };
}

/** As much of the CLI's `--output-format json` envelope as lawbook reads. */
function envelope(text) {
  const answer = judge(text);
  return {
    type: "result",
    subtype: "success",
    is_error: false,
    result: JSON.stringify(answer),
    structured_output: answer,
    usage: {
      input_tokens: Math.ceil(text.length / 4),
      output_tokens: 24,
      cache_read_input_tokens: 0,
      cache_creation_input_tokens: 0,
    },
  };
}

process.stdout.write(JSON.stringify(envelope(readFileSync(0, "utf8"))));
