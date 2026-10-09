import { createHash, randomUUID } from "node:crypto";

export const languages = [
  ["zh", "简体中文"], ["en", "英语"], ["jp", "日语"], ["kor", "韩语"],
  ["cht", "繁体中文"], ["yue", "粤语"], ["fra", "法语"], ["de", "德语"],
  ["spa", "西班牙语"], ["ru", "俄语"], ["pt", "葡萄牙语"], ["it", "意大利语"],
  ["th", "泰语"], ["ara", "阿拉伯语"], ["vie", "越南语"],
] as const;
export type Preferences = { appid: string; secret: string; target: string };
export type Translation = { text: string; from: string; to: string };
const errors: Record<string, string> = {
  "52001": "百度服务超时，请稍后重试", "52002": "百度服务异常，请稍后重试",
  "52003": "APP ID 无效，请检查扩展设置", "54000": "请求参数不完整",
  "54001": "签名错误，请检查 APP ID 和密钥", "54003": "请求过于频繁，请稍后重试",
  "54004": "账户余额不足，请检查百度翻译账户", "54005": "长文本请求过于频繁，请稍后重试",
  "58000": "客户端 IP 不在百度平台允许范围内", "58001": "该语言方向不受支持",
  "58002": "翻译服务未开通，请在百度平台开通通用翻译 API",
  "90107": "账户认证未通过，请检查百度平台认证状态",
};

export function requestBody(text: string, from: string, to: string, prefs: Preferences, salt: string) {
  if (!text.trim()) throw new Error("请输入需要翻译的内容");
  if (Buffer.byteLength(text, "utf8") > 6000) throw new Error("单次翻译请勿超过 6000 UTF-8 字节，请分段翻译");
  if (!prefs.appid.trim() || !prefs.secret.trim()) throw new Error("请先在扩展设置中填写 APP ID 和密钥");
  if (to === "auto") throw new Error("目标语言不能是自动检测");
  const appid = prefs.appid.trim();
  const sign = createHash("md5").update(appid + text + salt + prefs.secret.trim()).digest("hex");
  return new URLSearchParams({ q: text, from, to, appid, salt, sign }).toString();
}

export async function translate(text: string, from: string, to: string, prefs: Preferences, signal: AbortSignal, fetcher: typeof fetch = fetch): Promise<Translation> {
  const response = await fetcher("https://fanyi-api.baidu.com/api/trans/vip/translate", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: requestBody(text, from, to, prefs, randomUUID()), signal,
  });
  if (!response.ok) throw new Error(`百度请求失败（HTTP ${response.status}）`);
  const data = await response.json();
  if (data?.error_code && String(data.error_code) !== "52000") {
    const code = String(data.error_code);
    throw new Error(errors[code] ?? `百度翻译失败（错误码 ${code}）`);
  }
  if (!Array.isArray(data?.trans_result) || !data.trans_result.length ||
      !data.trans_result.every((item: { dst?: unknown }) => item && typeof item.dst === "string") ||
      typeof data.from !== "string" || typeof data.to !== "string") {
    throw new Error("百度返回了无效的翻译结果，请重试");
  }
  return { text: data.trans_result.map((item: { dst: string }) => item.dst).join("\n"), from: data.from, to: data.to };
}
