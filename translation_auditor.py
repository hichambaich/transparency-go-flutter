# -*- coding: utf-8 -*-
import re, sys
from pathlib import Path

UI_PATTERNS = [
    (r"""\bText\(\s*textDirection:\s*[^,]+,\s*(['"])((?:[^'"\\]|\\.)+)\1""", "Text(with dir)"),
    (r"""\bText\(\s*(['"])((?:[^'"\\]|\\.)+)\1""", "Text"),
    (r"""\b(?:label|hint|helper|error)Text\s*:\s*(['"])((?:[^'"\\]|\\.)+)\1""", "InputDecoration"),
    (r"""\b(?:tooltip|semanticLabel)\s*:\s*(['"])((?:[^'"\\]|\\.)+)\1""", "Accessibility"),
    (r"""\b(?:title|subtitle|label)\s*:\s*(['"])((?:[^'"\\]|\\.)+)\1""", "Widget prop"),
]

EXCLUDE_PATTERNS = [
    r"^[a-z][a-z0-9_]*$",
    r"^[A-Z][A-Z0-9_]*$",
    r"^#[0-9a-fA-F]{3,8}$",
    r"^https?://",
    r"^assets?/",
    r"^[a-z0-9_\-]+\.(png|jpg|svg|json|ttf)$",
    r"^[{}\[\]()<>\s,.;:!?\-_=+*/%|&^~`]+$",
    r"^[\d\s.,:%\-+*/()$]+$",
    r"^\s*$",
    r"^(en|ar|dark|light|true|false)$",
    r"^(auth_token|app_language|admin_backup_token)$",
    r"^(UNKNOWN|N/A|RUNNING|SUSPENDED|ACTIVE|DETERIORATING)$",
    r"^(SUSPEND|WARN|RECONNECT)$",
    r"^(BUY|SELL|DCA|ADOPTION)$",
]

def is_translatable(s):
    s = s.strip()
    if len(s) < 2: return False
    if not re.search(r"[A-Za-z]", s): return False
    for pat in EXCLUDE_PATTERNS:
        if re.match(pat, s): return False
    return True

def is_wrapped(content, pos, lit_end):
    ctx = content[max(0, pos-120):pos]
    if 'AppTranslations.t(' in ctx or 'AppTranslations.' in ctx:
        return True
    i = pos - 1
    while i >= 0 and content[i].isspace(): i -= 1
    if i >= 0 and content[i] == '(':
        j = i - 1
        while j >= 0 and content[j].isspace(): j -= 1
        end = j + 1
        while j >= 0 and (content[j].isalnum() or content[j] in '_$'):
            j -= 1
        fn = content[j+1:end]
        if fn == 't' or fn == 'tr': return True
    j = lit_end
    while j < len(content) and content[j] in ' \t': j += 1
    if j < len(content) and content[j] == '.':
        k = j + 1
        while k < len(content) and (content[k].isalnum() or content[k] == '_'): k += 1
        if content[j+1:k] in {'t', 'tr', 'translate'}: return True
    return False

def audit_file(path):
    try:
        content = path.read_text(encoding="utf-8")
    except:
        return []
    lines = content.split("\n")
    findings = []
    for pattern, category in UI_PATTERNS:
        for m in re.finditer(pattern, content, re.MULTILINE):
            text = m.group(2)
            if not is_translatable(text): continue
            lit_pos = m.start(2)
            if is_wrapped(content, m.start(), m.end(2)): continue
            line_num = content[:lit_pos].count("\n") + 1
            snippet = lines[line_num-1].strip()[:120] if line_num-1 < len(lines) else ''
            findings.append((line_num, text, category, snippet))
    seen, uniq = set(), []
    for f in findings:
        if (f[0], f[1]) not in seen:
            seen.add((f[0], f[1]))
            uniq.append(f)
    return uniq

def main():
    main_file = Path('/root/flutter_app/lib/main.dart')
    print("Auditing: %s\n" % main_file)
    findings = audit_file(main_file)
    if not findings:
        print("OK: No untranslated strings found (within tool scope).")
    else:
        for line, text, cat, snip in sorted(findings):
            print("  L%-5d [%-18s] '%s'" % (line, cat, text))
            print("           -> %s" % snip)
    print("\n" + "="*64)
    print("Total: %d untranslated strings" % len(findings))
    print("(This is a LOWER BOUND, not an upper bound -- patterns invisible to this tool:")
    print(" Text(someVariable), generated strings, strings outside main.dart)")
    return 0 if not findings else 1

if __name__ == "__main__":
    sys.exit(main())
