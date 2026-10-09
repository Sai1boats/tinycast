import { build } from "esbuild";
import { cp, mkdir, readFile, writeFile } from "node:fs/promises";
await mkdir("dist", { recursive: true });
const manifest = JSON.parse(await readFile("package.json", "utf8"));
await build({ entryPoints: manifest.commands.map(({ name }) => `src/${name}.tsx`), outdir: "dist", bundle: true, format: "cjs", platform: "node", target: "es2022", jsx: "automatic", external: ["@raycast/api", "react", "react/jsx-runtime"], minify: true });
await writeFile("dist/package.json", JSON.stringify(manifest, null, 2));
await cp("assets", "dist/assets", { recursive: true });
console.log("Tinycast 安装目录：dist/");
