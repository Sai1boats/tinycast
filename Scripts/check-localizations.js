#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const root = path.join(__dirname, "..", "Tinycast", "Resources");

function read(language, table) {
  const source = fs.readFileSync(path.join(root, `${language}.lproj`, `${table}.strings`), "utf8");
  const result = new Map();
  for (const line of source.trim().split("\n")) {
    const match = line.match(/^("(?:[^"\\]|\\.)*") = ("(?:[^"\\]|\\.)*");$/);
    if (!match) throw new Error(`Invalid .strings line: ${line}`);
    const key = JSON.parse(match[1]);
    if (result.has(key)) throw new Error(`Duplicate ${language} key: ${key}`);
    result.set(key, JSON.parse(match[2]));
  }
  return result;
}

function argumentsIn(value) {
  const result = new Map();
  let index = 0;
  for (const match of value.matchAll(/(?<!%)%(?!%)(?:(\d+)\$)?[-+0 #]*\d*(?:\.\d+)?(ll|l|z|t|h)?([@diufgeGs])/g)) {
    index += 1;
    result.set(Number(match[1] || index), (match[2] || "") + match[3]);
  }
  return JSON.stringify([...result].sort((a, b) => a[0] - b[0]));
}

let count = 0;
for (const table of ["Localizable", "InfoPlist"]) {
  const english = read("en", table);
  const chinese = read("zh-Hans", table);
  if (english.size !== chinese.size) throw new Error(`${table}: language key counts differ`);
  for (const [key, source] of english) {
    const translation = chinese.get(key);
    if (!translation) throw new Error(`${table}: missing Chinese translation for ${key}`);
    if (argumentsIn(source) !== argumentsIn(translation)) {
      throw new Error(`${table}: format arguments differ for ${key}`);
    }
    count += 1;
  }
}
console.log(`✓ ${count} bilingual resource keys; format arguments match`);
