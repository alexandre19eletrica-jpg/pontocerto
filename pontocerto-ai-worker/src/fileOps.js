import fs from 'fs/promises';
import path from 'path';
import { resolveUnderRoot } from './pathGuard.js';

export async function readTextFile(projectRoot, relativePath) {
  const full = resolveUnderRoot(projectRoot, relativePath);
  return fs.readFile(full, 'utf8');
}

export async function writeTextFile(projectRoot, relativePath, content) {
  const full = resolveUnderRoot(projectRoot, relativePath);
  await fs.mkdir(path.dirname(full), { recursive: true });
  await fs.writeFile(full, content, 'utf8');
}

export async function listDir(projectRoot, relativeDir = '.') {
  const full = resolveUnderRoot(projectRoot, relativeDir);
  const entries = await fs.readdir(full, { withFileTypes: true });
  return entries.map((e) => ({
    name: e.name,
    type: e.isDirectory() ? 'dir' : 'file',
  }));
}
