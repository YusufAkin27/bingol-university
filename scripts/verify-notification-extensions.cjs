// Validates the iOS extension target graph without requiring Xcode or third-party packages.
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const input = fs.readFileSync(path.join(root, 'mobile/ios/Runner.xcodeproj/project.pbxproj'), 'utf8');
let position = 0;
function token() {
  while (position < input.length) {
    if (/\s/.test(input[position])) { position++; continue; }
    if (input.startsWith('//', position)) { position = input.indexOf('\n', position); continue; }
    if (input.startsWith('/*', position)) { position = input.indexOf('*/', position) + 2; continue; }
    break;
  }
  const start = position;
  if ('{}()=;,'.includes(input[position])) return input[position++];
  if (input[position] === '"') {
    position++;
    while (position < input.length) {
      if (input[position] === '\\') { position += 2; continue; }
      if (input[position++] === '"') break;
    }
    return JSON.parse(input.slice(start, position));
  }
  while (position < input.length && !/[\s{}()=;,]/.test(input[position])) position++;
  return input.slice(start, position);
}
let current = token();
function take(expected) {
  if (current !== expected) throw Error(`Expected ${expected}, got ${current} at ${position}`);
  current = token();
}
function value() {
  if (current === '{') {
    take('{'); const result = {};
    while (current !== '}') { const key = current; current = token(); take('='); result[key] = value(); take(';'); }
    take('}'); return result;
  }
  if (current === '(') {
    take('('); const result = [];
    while (current !== ')') { result.push(value()); if (current === ',') take(','); else if (current !== ')') throw Error('Missing array comma'); }
    take(')'); return result;
  }
  const result = current; current = token(); return result;
}
const project = value();
const objects = project.objects;
const runner = Object.values(objects).find(o => o.isa === 'PBXNativeTarget' && o.name === 'Runner');
for (const name of ['NotificationService', 'NotificationContent']) {
  const entry = Object.entries(objects).find(([, o]) => o.isa === 'PBXNativeTarget' && o.name === name);
  if (!entry) throw Error(`Missing ${name} target`);
  const [id, target] = entry;
  if (!objects[project.rootObject].targets.includes(id)) throw Error(`${name} missing from project targets`);
  if (!runner.dependencies.some(d => objects[d].target === id)) throw Error(`Runner does not depend on ${name}`);
  const embedded = runner.buildPhases.map(p => objects[p]).filter(p => p.isa === 'PBXCopyFilesBuildPhase' && p.dstSubfolderSpec === '13');
  if (!embedded.some(p => p.files.some(f => objects[f].fileRef === target.productReference))) throw Error(`${name} is not embedded`);
  const configs = objects[target.buildConfigurationList].buildConfigurations.map(c => objects[c]);
  if (configs.length !== 3 || configs.some(c => c.buildSettings.APPLICATION_EXTENSION_API_ONLY !== 'YES')) throw Error(`Invalid ${name} build configurations`);
  for (const config of configs) {
    if (!fs.existsSync(path.join(root, 'mobile/ios', config.buildSettings.INFOPLIST_FILE))) throw Error(`Missing ${name} plist`);
  }
  console.log(`${name}: target, build configurations, Runner dependency and app embedding verified`);
}
