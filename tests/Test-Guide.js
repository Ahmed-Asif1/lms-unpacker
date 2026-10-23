// Offline guide behavior checks using Node's built-ins; no browser or network required.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
function checkOfflinePage(relative) {
  const filename = path.join(__dirname, '..', relative);
  const page = fs.readFileSync(filename, 'utf8');
  const pageIds = [...page.matchAll(/\bid="([^"]+)"/g)].map(m => m[1]);
  assert.equal(new Set(pageIds).size, pageIds.length, `${relative}: duplicate IDs`);
  for (const match of page.matchAll(/href="([^"]+)"/g)) {
    const href = match[1];
    if (href.startsWith('#')) assert(pageIds.includes(href.slice(1)), `${relative}: missing anchor ${href}`);
    else if (!/^[a-z]+:/i.test(href)) assert(fs.existsSync(path.resolve(path.dirname(filename), href)), `${relative}: missing local link ${href}`);
  }
  assert(!/<(?:script|link|img|iframe)\b[^>]*(?:src|href)=["']https?:/i.test(page), `${relative}: remote asset`);
  return page;
}
const html = fs.readFileSync(path.join(__dirname, '..', 'START-HERE.html'), 'utf8');
const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(m => m[1]);
assert.equal(new Set(ids).size, ids.length, 'HTML IDs must be unique');
for (const match of html.matchAll(/href="#([^"]+)"/g)) assert(ids.includes(match[1]), `Missing anchor ${match[1]}`);
assert(!/<(?:script|link|img|iframe)\b[^>]*(?:src|href)=["']https?:/i.test(html), 'Guide must work without remote assets');
const nodes = new Map();
function node(attributes = {}, text = '') {
  return {dataset: {}, textContent: text, value: '', checked: false, hidden: false, disabled: false, attributes,
    events: {}, addEventListener(event, callback) { this.events[event] = callback; },
    setAttribute(key, value) { this.attributes[key] = value; }, removeAttribute(key) { delete this.attributes[key]; }, focus() {},
    async fire(event) { if (this.events[event]) await this.events[event](); }};
}
for (const id of ids) nodes.set(id, node());
nodes.get('demo-depth').value = '1';
nodes.get('group-by').value = 'Category';
nodes.get('calculus-group').value = 'Week';
const modes = ['Flatten', 'Extract', 'Organize'].map(mode => Object.assign(node(), {dataset: {mode}}));
const steps = [0, 1, 2, 3, 4].map(step => Object.assign(node(), {dataset: {step: String(step)}}));
const topics = [...html.matchAll(/<details data-help-topic>([\s\S]*?)<\/details>/g)].map(m => node({}, m[1].replace(/<[^>]*>/g, ' ')));
const document = {
  getElementById(id) { assert(nodes.has(id), `Unknown element ${id}`); return nodes.get(id); },
  querySelectorAll(selector) { return {'[data-mode]': modes, '[data-step]': steps, '[data-help-topic]': topics}[selector] || []; },
  createRange() { return {selectNodeContents() {}}; }};
const context = {document, navigator: {}, window: {getSelection() { return {removeAllRanges() {}, addRange() {}}; }}};
const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]).join('\n');
vm.runInNewContext(script, context, {timeout: 1000});
(async () => {
  assert.match(nodes.get('demo-scan-status').textContent, /^2 ZIPs/);
  nodes.get('demo-depth').value = '0'; await nodes.get('demo-depth').fire('change');
  assert.equal(nodes.get('demo-found').textContent, 'general.zip');
  nodes.get('demo-depth').value = '1'; await nodes.get('demo-depth').fire('change');
  assert.match(nodes.get('demo-found').textContent, /Calculus\/lecture.zip/);
  nodes.get('help-search').value = 'workspace'; await nodes.get('help-search').fire('input');
  assert(topics.some(topic => !topic.hidden) && topics.some(topic => topic.hidden));
  nodes.get('help-search').value = 'no-such-topic-493'; await nodes.get('help-search').fire('input');
  assert(topics.every(topic => topic.hidden)); assert.match(nodes.get('help-search-status').textContent, /No topics match/);
  nodes.get('help-search').value = ''; await nodes.get('help-search').fire('input');
  assert(topics.every(topic => !topic.hidden));
  for (const mode of modes) {
    await mode.fire('click');
    for (const group of ['Category', 'Week', 'Topic']) {
      nodes.get('group-by').value = group; await nodes.get('group-by').fire('change');
      for (const keep of [false, true]) {
        nodes.get('keep-zip').checked = keep; await nodes.get('keep-zip').fire('change');
        assert.equal(nodes.get('zip-label').textContent, keep ? 'ZIP KEPT' : 'ZIP DELETED');
        assert(nodes.get('result-tree').textContent.includes('Quantitative/'));
      }
    }
  }
  for (const step of steps) { await step.fire('click'); assert.match(nodes.get('step-count').textContent, /^Step [1-5] of 5$/); }
  nodes.get('calculus-group').value = 'Topic'; await nodes.get('calculus-group').fire('change');
  assert.match(nodes.get('calculus-tree').textContent, /Limits and continuity/);
  await nodes.get('copy-launch').fire('click'); assert.match(nodes.get('launch-status').textContent, /Ctrl\+C/);
  await nodes.get('copy-command').fire('click'); assert.match(nodes.get('copy-status').textContent, /Ctrl\+C/);
  console.log('PASS: Offline HTML, anchors, scan depth, searchable help, all modes/groupings, CLI steps, Calculus and clipboard fallback');
  const handbook = checkOfflinePage('docs/BUILD-IT-YOURSELF.html');
  const demo = new Map(['policy','same','keep','conflict-result'].map(id => [id,node()]));
  demo.get('policy').value='Skip'; demo.get('same').value='different'; demo.get('keep').value='delete';
  const handbookScript = [...handbook.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n');
  vm.runInNewContext(handbookScript,{document:{getElementById(id){assert(demo.has(id));return demo.get(id);}}},{timeout:1000});
  for (const policy of ['Skip','Rename','Overwrite']) for (const same of ['same','different']) for (const keep of ['keep','delete']) {
    demo.get('policy').value=policy; demo.get('same').value=same; demo.get('keep').value=keep;
    await demo.get('policy').fire('change');
    const result=demo.get('conflict-result').textContent;
    assert(result.includes(same==='same'?'Duplicate':policy==='Rename'?'lecture_1.pdf':policy));
    assert(result.includes(keep==='keep'?'Source ZIP: kept':'Source ZIP: permanently deleted'));
  }
  const reference=checkOfflinePage('docs/CODE-REFERENCE.html');
  assert(reference.includes('Invoke-LmsArchive') && reference.includes('Desktop.xaml'));
  const entries=[...reference.matchAll(/<article data-entry[^>]*>([\s\S]*?)<\/article>/g)].map(m=>node({},m[1]));
  const search=node(), count=node();
  vm.runInNewContext([...reference.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m=>m[1]).join('\n'),{document:{querySelectorAll(){return entries;},getElementById(id){return id==='search'?search:count;}}},{timeout:1000});
  search.value='Copy-LmsEntry'; await search.fire('input');
  assert(entries.some(entry=>!entry.hidden) && entries.some(entry=>entry.hidden));
  // The reference embeds this test's source, so a fixed test phrase would match itself.
  search.value='unfindable '+Date.now()+' '+Math.random(); await search.fire('input'); assert(entries.every(entry=>entry.hidden));
  assert.match(count.textContent,/No matches/);
  search.value=''; await search.fire('input'); assert(entries.every(entry=>!entry.hidden));
  console.log('PASS: Handbook links, twelve collision/retention scenarios, complete reference and searchable source');
})().catch(error => { console.error(error); process.exitCode = 1; });
