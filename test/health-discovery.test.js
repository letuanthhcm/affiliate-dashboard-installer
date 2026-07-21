'use strict';
const assert = require('assert');
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const installer = fs.readFileSync(path.join(__dirname, '..', 'install.sh'), 'utf8');
const match = installer.match(/\/\/ HEALTH_RESOLVER_NODE_BEGIN\n([\s\S]*?)\/\/ HEALTH_RESOLVER_NODE_END/);
assert.ok(match, 'embedded health resolver must be test-addressable');
const resolver = match[1];

function put(root, relative, content, mode) {
  const file = path.join(root, relative); fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, content);
  if (mode) fs.chmodSync(file, mode);
}
function resolve({ args, env = {}, config, ecosystem, pid = 4242, socketPort }) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'health-discovery-'));
  if (config) put(root, 'config/app.js', config);
  if (ecosystem) put(root, 'ecosystem.config.js', ecosystem);
  const bin = path.join(root, 'bin'); fs.mkdirSync(bin);
  if (socketPort) {
    put(root, 'bin/lsof.cmd', `@echo off\r\necho node ${pid} owner 1u IPv4 0t0 TCP *:${socketPort} ^(LISTEN^)\r\n`);
    put(root, 'bin/lsof', `#!/usr/bin/env bash\nprintf 'node ${pid} owner 1u IPv4 0t0 TCP *:${socketPort} (LISTEN)\\n'\n`, 0o755);
  }
  const selected = { name: 'affiliatecms7', pid, pm2_env: { pm_cwd: root, pm_exec_path: path.join(root, 'server.js'), args, env } };
  const result = cp.spawnSync(process.execPath, ['-e', resolver], { encoding: 'utf8', env: { ...process.env, PATH: `${bin}${path.delimiter}${process.env.PATH}`, PM2_JSON: JSON.stringify([selected]), NAME: selected.name, APP_DIR: root } });
  return { status: result.status, output: result.stdout, stderr: result.stderr };
}
function expect(options, output) { const result = resolve(options); assert.strictEqual(result.status, 0, result.stderr); assert.strictEqual(result.output, output); }

expect({ args: '--port=8007' }, 'PM2_ARGS|8007');
expect({ env: { APP_PORT: '8008' } }, 'PM2_ENV_APP_PORT|8008');
expect({ config: "module.exports={port: argv.port || 8009};\n" }, 'CONFIG_APP_JS|8009');
expect({ ecosystem: "module.exports={apps:[{name:'affiliatecms7',args:'--port=8010'}]};\n" }, 'ECOSYSTEM_ARGS|8010');
expect({ socketPort: 8011 }, 'PID_SOCKET|8011');
expect({ args: '--port=8012', env: { PORT: '8012' }, config: 'module.exports={port:8012};', ecosystem: "module.exports={apps:[{name:'affiliatecms7',args:'--port=8012'}]};", socketPort: 8012 }, 'PM2_ARGS|8012');
expect({ args: '--port=8013', config: 'module.exports={port:9013};', socketPort: 9014 }, 'PM2_ARGS|8013');
expect({ config: 'module.exports={port:8014};', socketPort: 9014 }, 'CONFIG_APP_JS|8014');
const unresolved = resolve({}); assert.notStrictEqual(unresolved.status, 0); assert.strictEqual(unresolved.output, '');
console.log('health discovery priority fixtures passed');
