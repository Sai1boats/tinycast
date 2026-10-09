import { strict as assert } from "node:assert";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { requestBody, translate } from "../src/baidu";
const prefs = { appid: "test-app", secret: "test-secret", target: "zh" };
const signal = new AbortController().signal;
const reply = (data: unknown, status = 200) => (async () => new Response(JSON.stringify(data), { status })) as typeof fetch;
test("signs the unescaped original and form-encodes Unicode and reserved characters", () => {
  const text = "你好 & +\nhello";
  const body = new URLSearchParams(requestBody(text, "auto", "en", prefs, "123"));
  assert.equal(body.get("q"), text);
  assert.equal(body.get("sign"), createHash("md5").update(`test-app${text}123test-secret`).digest("hex"));
  assert.equal(body.has("secret"), false);
});
test("validates credentials, blank input and UTF-8 byte limit", () => {
  assert.throws(() => requestBody(" ", "auto", "zh", prefs, "s"));
  assert.throws(() => requestBody("a", "auto", "zh", { ...prefs, secret: "" }, "s"));
  assert.throws(() => requestBody("中".repeat(2001), "auto", "zh", prefs, "s"));
  assert.doesNotThrow(() => requestBody("中".repeat(2000), "auto", "zh", prefs, "s"));
  assert.throws(() => requestBody("a", "en", "auto", prefs, "s"));
});
test("sends HTTPS POST with cancellation and preserves paragraph results", async () => {
  const fetcher = (async (url, init) => {
    assert.equal(url, "https://fanyi-api.baidu.com/api/trans/vip/translate");
    assert.equal(init?.method, "POST");
    assert.equal(init?.signal, signal);
    assert.equal(new URLSearchParams(String(init?.body)).get("q"), "hello\nworld");
    return new Response(JSON.stringify({ from: "en", to: "zh", trans_result: [{ dst: "你好" }, { dst: "世界" }] }));
  }) as typeof fetch;
  assert.deepEqual(await translate("hello\nworld", "auto", "zh", prefs, signal, fetcher), { text: "你好\n世界", from: "en", to: "zh" });
});
test("reports service and HTTP errors and rejects malformed results", async () => {
  await assert.rejects(translate("a", "auto", "zh", prefs, signal, reply({ error_code: "54001" })), /签名错误/);
  await assert.rejects(translate("a", "auto", "zh", prefs, signal, reply({}, 503)), /HTTP 503/);
  for (const data of [null, {}, { from: "en", to: "zh", trans_result: [{ dst: 42 }] }]) {
    await assert.rejects(translate("a", "auto", "zh", prefs, signal, reply(data)), /无效/);
  }
});
