# 百度翻译 · Raycast / Tinycast 扩展

两个命令：**百度翻译**用于手动输入、多行文本或读取剪贴板；**百度翻译选中文本**在启动时读取前台应用选区并立即翻译。支持来源语言自动检测、15 种来源/目标语言选择、交换语言、复制译文和粘贴回前台应用。

## 安装到 Tinycast

已构建的 `dist/` 可直接使用：设置 → 扩展 → 启用扩展 → 安装新扩展 → 从文件夹添加，选择本扩展的 `dist` 目录。在扩展设置中填写百度 APP ID 和密钥，并选择默认目标语言。

重新构建：

```sh
npm ci
npm run build:tinycast
```

## 安装到 Raycast

需要 Node.js 22.14 或更新版本和 Raycast。进入本目录运行：

```sh
npm ci
npm run dev
```

开发命令会将扩展加载到 Raycast。首次启动时填写 APP ID 和密钥。可在 Raycast 扩展设置中给“百度翻译选中文本”分配快捷键。`npm run build` 可生成 Raycast 构建。

## 使用

1. 在任意应用选中文本，运行“百度翻译选中文本”，直接查看译文；无法读取时，可手动输入或读取剪贴板。
2. 或运行“百度翻译”，输入原文，选择来源/目标语言，使用“翻译”动作提交（表单提交为 ⌘↵）。
3. 在操作菜单中选择“粘贴译文到原应用”或“复制译文”。粘贴译文使用 ⌘⇧↵；复制使用 ⌘⇧C。
4. ⌘⇧V 将剪贴板内容读入原文，⌘⇧S 交换语言；已有译文时会将译文放入原文。自动检测模式需先成功翻译才能交换。
5. 修改原文或语言会清除旧结果并取消旧请求，重新选择“翻译”提交。

选区读取及粘贴需要宿主应用的辅助功能权限，且部分应用不提供可读取的选区。密钥通过宿主的 password 设置输入，不写入代码；扩展自身不保存原文、译文或翻译历史。执行翻译时会将原文发送给百度。请求最长等待 15 秒，不自动重试，单次限制 6000 UTF-8 字节。

本扩展使用百度**通用文本翻译 API**，不是百度智能云其他产品的 API Key / Secret Key。需要在百度翻译开放平台完成相应服务开通。没有真实凭据时，测试只使用模拟响应。

## 验证

```sh
npm run typecheck
npm test
npm run build:tinycast
```

实现依据：[百度通用翻译 API](https://fanyi-api.baidu.com/doc/21)、[Raycast Clipboard API](https://developers.raycast.com/api-reference/clipboard)、[Raycast Form API](https://developers.raycast.com/api-reference/user-interface/form)。
