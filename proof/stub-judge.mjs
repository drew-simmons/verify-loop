#!/usr/bin/env node
// A stand-in for the model, so the loop's model stage can be exercised with
// no credentials. Speaks just enough of the OpenAI chat-completions shape for
// lawbook's `openai` provider, and decides deterministically: a request fails
// the standard when a file carries the marker comment or is a fail fixture.
//
//   node proof/stub-judge.mjs            # listens on 127.0.0.1:47391
//   lawbook check . --config lawbook.stub.yaml
import { createServer } from "node:http";

const PORT = Number(process.env.STUB_JUDGE_PORT ?? 47391);
export const MARKER = "// stub: fails standard";

/** The user message's text, whether it came as a string or as content parts. */
function userText(body) {
  const user = body.messages?.find((message) => message.role === "user");
  const content = user?.content ?? "";
  return typeof content === "string" ? content : content.map((part) => part.text ?? "").join("\n");
}

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

function completion(body, raw) {
  const answer = judge(userText(body));
  return {
    id: `stub-${process.hrtime.bigint()}`,
    object: "chat.completion",
    created: Math.floor(Date.now() / 1000),
    model: body.model ?? "stub",
    choices: [
      {
        index: 0,
        message: { role: "assistant", content: JSON.stringify(answer), refusal: null },
        finish_reason: "stop",
      },
    ],
    usage: { prompt_tokens: Math.ceil(raw.length / 4), completion_tokens: 24, total_tokens: Math.ceil(raw.length / 4) + 24 },
  };
}

const server = createServer((request, response) => {
  if (request.method !== "POST" || !request.url.endsWith("/chat/completions")) {
    response.writeHead(404).end();
    return;
  }
  let raw = "";
  request.on("data", (chunk) => {
    raw += chunk;
  });
  request.on("end", () => {
    const reply = JSON.stringify(completion(JSON.parse(raw), raw));
    response.writeHead(200, { "content-type": "application/json" }).end(reply);
  });
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`stub judge listening on http://127.0.0.1:${PORT}/v1`);
});
