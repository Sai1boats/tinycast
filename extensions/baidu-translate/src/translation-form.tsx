import { Action, ActionPanel, Clipboard, Form, getPreferenceValues, getSelectedText, openExtensionPreferences, showToast, Toast } from "@raycast/api";
import { useEffect, useRef, useState } from "react";
import { languages, Preferences, translate, Translation } from "./baidu";

export default function TranslationForm({ selection }: { selection: boolean }) {
  const prefs = getPreferenceValues<Preferences>();
  const [text, setText] = useState("");
  const [from, setFrom] = useState("auto");
  const [to, setTo] = useState(prefs.target || "zh");
  const [result, setResult] = useState<Translation>();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();
  const generation = useRef(0);
  const request = useRef<AbortController | null>(null);

  function invalidate() {
    generation.current++;
    request.current?.abort();
    request.current = null;
    setBusy(false);
    setResult(undefined);
    setError(undefined);
  }

  async function run(input = text, source = from, target = to) {
    invalidate();
    const id = generation.current;
    const controller = new AbortController();
    request.current = controller;
    setBusy(true);
    let timedOut = false;
    const timer = setTimeout(() => { timedOut = true; controller.abort(); }, 15000);
    try {
      const translated = await translate(input, source, target, prefs, controller.signal);
      if (id === generation.current && !controller.signal.aborted) setResult(translated);
    } catch (cause) {
      if (id !== generation.current) return;
      const message = timedOut ? "请求超时，请检查网络后重试" : cause instanceof Error ? cause.message : "翻译失败，请重试";
      setError(message);
      await showToast({ style: Toast.Style.Failure, title: "翻译失败", message });
    } finally {
      clearTimeout(timer);
      if (id === generation.current) { setBusy(false); request.current = null; }
    }
  }

  useEffect(() => {
    let active = true;
    const id = generation.current;
    if (selection) {
      setBusy(true);
      void getSelectedText().then((selected) => {
        if (!active || id !== generation.current) return;
        if (!selected.trim()) throw new Error("未选中文本，请手动输入或从剪贴板读取");
        setText(selected);
        void run(selected);
      }).catch(() => {
        if (active && id === generation.current) {
          setBusy(false);
          setError("无法读取选中文本。请检查辅助功能权限，或手动输入、读取剪贴板。");
        }
      });
    }
    return () => { active = false; generation.current++; request.current?.abort(); };
  }, []);

  async function readClipboard() {
    invalidate();
    const id = generation.current;
    try {
      const value = await Clipboard.readText();
      if (id !== generation.current) return;
      if (!value?.trim()) throw new Error("剪贴板中没有文本");
      setText(value);
    } catch (cause) {
      if (id === generation.current) setError(cause instanceof Error ? cause.message : "读取剪贴板失败");
    }
  }

  function swap() {
    const source = from === "auto" ? result?.from : from;
    if (!source || source === "auto" || !languages.some(([code]) => code === source)) {
      setError("请先翻译以检测来源语言，或手动选择来源语言");
      return;
    }
    const nextText = result?.text ?? text;
    invalidate();
    setText(nextText);
    setFrom(to);
    setTo(source);
  }

  return <Form isLoading={busy} navigationTitle="百度翻译" actions={<ActionPanel>
    <Action.SubmitForm title="翻译" onSubmit={() => { void run(); }} />
    {result && <Action.Paste title="粘贴译文到原应用" content={result.text} shortcut={{ modifiers: ["cmd", "shift"], key: "return" }} />}
    {result && <Action.CopyToClipboard title="复制译文" content={result.text} shortcut={{ modifiers: ["cmd", "shift"], key: "c" }} />}
    <Action title="从剪贴板读取原文" onAction={readClipboard} shortcut={{ modifiers: ["cmd", "shift"], key: "v" }} />
    <Action title="交换来源和目标语言" onAction={swap} shortcut={{ modifiers: ["cmd", "shift"], key: "s" }} />
    <Action title="配置 APP ID 和密钥" onAction={openExtensionPreferences} />
  </ActionPanel>}>
    <Form.TextArea id="text" title="原文" placeholder="输入或粘贴需要翻译的内容" value={text} onChange={(value) => { invalidate(); setText(value); }} error={error} />
    <Form.Dropdown id="from" title="来源语言" value={from} onChange={(value) => { invalidate(); setFrom(value); }}>
      <Form.Dropdown.Item value="auto" title="自动检测" />
      {languages.map(([value, title]) => <Form.Dropdown.Item key={value} value={value} title={title} />)}
    </Form.Dropdown>
    <Form.Dropdown id="to" title="目标语言" value={to} onChange={(value) => { invalidate(); setTo(value); }}>
      {languages.map(([value, title]) => <Form.Dropdown.Item key={value} value={value} title={title} />)}
    </Form.Dropdown>
    <Form.Separator />
    <Form.Description title="译文" text={result?.text ?? (busy ? "正在翻译…" : "提交翻译后，结果将在这里显示。")} />
    {result && <Form.Description title="语言方向" text={`${result.from} → ${result.to}`} />}
  </Form>;
}
