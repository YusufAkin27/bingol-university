"""Backend kaynak kodundan modul haritasi cikarir (yalniz okur). Kullanim: python -I -X utf8 extract_map.py <repo> <out.json>"""
import json, os, re, sys, collections

repo, out = sys.argv[1], sys.argv[2]
ROOT = os.path.join(repo, 'backend', 'src', 'main', 'java', 'edu', 'bingol', 'backend')
MIG = os.path.join(repo, 'backend', 'src', 'main', 'resources', 'db', 'migration')

RE_IMPORT = re.compile(r'^import\s+(?:static\s+)?edu\.bingol\.backend\.([a-z0-9_]+)', re.M)
RE_CLASS_MAP = re.compile(r'@RequestMapping\(\s*(?:value\s*=\s*|path\s*=\s*)?\{?\s*"([^"]*)"')
RE_METHOD_MAP = re.compile(r'@(Get|Post|Put|Patch|Delete)Mapping(?:\(\s*(?:(?:value|path)\s*=\s*)?\{?\s*(?:"([^"]*)")?[^)]*\))?')
RE_TABLE = re.compile(r'@Table\(\s*(?:name\s*=\s*)?"([^"]+)"')
RE_CLASS = re.compile(r'\b(?:public\s+)?(?:final\s+|abstract\s+)?(class|interface|record|enum)\s+([A-Z]\w+)')
RE_SCHED = re.compile(r'@Scheduled\(([^)]*)\)\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:public\s+|protected\s+|private\s+)?(?:\w+\s+)?(\w+)\s*\(')
RE_IMPL = re.compile(r'\bimplements\s+([^{]+)\{')
SPIS = ['ReportTargetHandler', 'SearchProvider', 'DataExporter', 'AccountDataPurger']
EXT = {
    'Redis': re.compile(r'StringRedisTemplate|RedisTemplate|RedisConnection|RateLimiter\b'),
    'FCM': re.compile(r'FirebaseMessaging|com\.google\.firebase'),
    'SMTP': re.compile(r'JavaMailSender|MimeMessage'),
    'Kaynak siteler': re.compile(r'org\.jsoup|Jsoup\.'),
    'WebSocket/STOMP': re.compile(r'SimpMessagingTemplate|StompHeaderAccessor|@MessageMapping'),
    'Dosya deposu': re.compile(r'\bFileStorage\b'),
    'Google/Apple OAuth': re.compile(r'JwksKeyProvider|OAuthTokenVerifier|appleid\.apple\.com|accounts\.google\.com'),
}

mods = collections.OrderedDict()
edges = collections.Counter()

def mod(name):
    return mods.setdefault(name, dict(id=name, files=0, lines=0, subpackages=set(), controllers=[], endpoints=[],
                                      entities=[], tables=[], jobs=[], services=[], repositories=0, spi=[], ext=set(),
                                      filters=[], listeners=0))

for dirpath, _, files in os.walk(ROOT):
    rel = os.path.relpath(dirpath, ROOT).replace('\\', '/')
    if rel == '.':
        continue
    top = rel.split('/')[0]
    m = mod(top)
    if '/' in rel:
        m['subpackages'].add(rel.split('/', 1)[1])
    for f in files:
        if not f.endswith('.java'):
            continue
        src = open(os.path.join(dirpath, f), encoding='utf-8', errors='replace').read()
        m['files'] += 1
        m['lines'] += src.count('\n') + 1
        for dep in set(RE_IMPORT.findall(src)):
            if dep != top:
                edges[(top, dep)] += 1
        cm = RE_CLASS.search(src)
        cname = cm.group(2) if cm else f[:-5]
        for k, rx in EXT.items():
            if rx.search(src):
                m['ext'].add(k)
        if '@Entity' in src:
            m['entities'].append(cname)
            t = RE_TABLE.search(src)
            if t:
                m['tables'].append(t.group(1))
        if re.search(r'extends\s+(Jpa|Crud|Paging)\w*Repository|\bRepository<', src):
            m['repositories'] += 1
        if re.search(r'^@Service\b', src, re.M):
            m['services'].append(cname)
        if re.search(r'extends\s+OncePerRequestFilter|implements\s+Filter\b', src):
            m['filters'].append(cname)
        if '@EventListener' in src or '@TransactionalEventListener' in src:
            m['listeners'] += 1
        im = RE_IMPL.search(src)
        if im:
            for s in SPIS:
                if re.search(r'\b' + s + r'\b', im.group(1)):
                    m['spi'].append(f'{s}: {cname}')
        for args, meth in RE_SCHED.findall(src):
            a = re.sub(r'\s+', ' ', args).strip()
            m['jobs'].append(dict(cls=cname, method=meth, when=a[:110]))
        if re.search(r'@(Rest)?Controller\b', src):
            base = ''
            head = src[:cm.start()] if cm else src
            b = RE_CLASS_MAP.search(head)
            if b:
                base = b.group(1)
            eps = []
            body = src[cm.start():] if cm else src
            for verb, path in RE_METHOD_MAP.findall(body):
                p = (base.rstrip('/') + '/' + (path or '').lstrip('/')).rstrip('/') or '/'
                eps.append(f'{verb.upper()} {p}')
            m['controllers'].append(dict(name=cname, base=base, count=len(eps)))
            m['endpoints'].extend(eps)

migs = sorted(os.listdir(MIG)) if os.path.isdir(MIG) else []
ver = [int(re.match(r'V(\d+)', x).group(1)) for x in migs if re.match(r'V(\d+)', x)]

nodes = []
for m in mods.values():
    m['subpackages'] = sorted(m['subpackages'])
    m['ext'] = sorted(m['ext'])
    m['endpoints'] = sorted(set(m['endpoints']))
    m['tables'] = sorted(set(m['tables']))
    m['entities'] = sorted(set(m['entities']))
    m['services'] = sorted(set(m['services']))
    nodes.append(m)

links = [dict(source=a, target=b, weight=w) for (a, b), w in sorted(edges.items()) if a in mods and b in mods]
data = dict(
    generatedFrom=dict(branch=os.popen(f'git -C "{repo}" branch --show-current').read().strip(),
                       commit=os.popen(f'git -C "{repo}" log -1 --format=%h').read().strip()),
    totals=dict(modules=len(nodes), files=sum(n['files'] for n in nodes), lines=sum(n['lines'] for n in nodes),
                endpoints=sum(len(n['endpoints']) for n in nodes), entities=sum(len(n['entities']) for n in nodes),
                jobs=sum(len(n['jobs']) for n in nodes), migrations=len(migs), maxMigration=max(ver) if ver else 0),
    nodes=nodes, links=links, migrations=migs)
json.dump(data, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(json.dumps(data['totals']), len(links), 'baglanti')
top = sorted(nodes, key=lambda n: -n['files'])[:12]
print([(n['id'], n['files'], len(n['endpoints']), len(n['entities'])) for n in top])
