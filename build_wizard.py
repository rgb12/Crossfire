#!/usr/bin/env python3
"""
build_wizard.py - Crossfire config wizard generator

Reads config.lua and produces a standalone config_wizard.html that lets a user
edit every value in a simple browser UI and download a config.json.

Run it again after every config.lua change to rebuild the wizard:

    python3 build_wizard.py                 # config.lua -> config_wizard.html
    python3 build_wizard.py myconf.lua out.html

Design decisions (agreed with the project owner):
  * Lua enum tokens (AITaskTypes.JTAC, coalition.side.BLUE, Eras.MODERN, ...)
    are emitted as BARE string tokens: "JTAC", "BLUE", "MODERN". The mission's
    Lua loader is responsible for mapping these strings back to real enums.
  * Arithmetic expressions (4*51, 10*60+8, 118.250*1e6) are EVALUATED to a
    single number and stored as that number.
  * The whole file is walked automatically. Both Config and GroupData (and any
    other top-level table assignment) are exposed. No per-field curation needed.

The Lua we parse is the restricted subset this config file uses: table
constructors, numbers, arithmetic (+ - * / and parentheses), strings, booleans,
nil, dotted identifier tokens (treated as enum strings) and [expr] = value keys.
That is intentionally not a full Lua parser; it only needs to handle this file.
"""

import sys
import json
import re
from pathlib import Path


# --------------------------------------------------------------------------- #
# Tokenizer
# --------------------------------------------------------------------------- #

class Tok:
    def __init__(self, kind, value, pos, line):
        self.kind = kind      # 'num','str','name','bool','nil','punct'
        self.value = value
        self.pos = pos
        self.line = line

    def __repr__(self):
        return f"Tok({self.kind},{self.value!r})"


# A "comment" we keep around so the UI can show field help text.
class Comment:
    def __init__(self, text, line, inline):
        self.text = text       # cleaned comment text (no leading --)
        self.line = line
        self.inline = inline   # True if it trailed code on the same line


def strip_comments(src):
    """Remove Lua comments from the source but record them with their line
    numbers and whether they were inline (trailing code) or standalone.
    Returns (clean_source, comments_list)."""
    comments = []
    out = []
    i = 0
    n = len(src)
    line = 1
    # track whether anything non-space has appeared on the current line of OUTPUT
    line_has_code = False

    while i < n:
        c = src[i]

        # long comment --[[ ... ]] (also --[==[ ]==])
        if c == '-' and src.startswith('--', i):
            j = i + 2
            # long bracket?
            m = re.match(r'\[(=*)\[', src[j:])
            if m:
                eq = m.group(1)
                close = ']' + eq + ']'
                end = src.find(close, j + len(m.group(0)))
                if end == -1:
                    end = n
                else:
                    end = end + len(close)
                block = src[j + len(m.group(0)):end - len(close)] if end != n else src[j:]
                text = block.strip()
                comments.append(Comment(text, line, inline=line_has_code))
                # advance, counting newlines. Emit the SAME number of newlines
                # into the cleaned output so downstream line numbers (used by the
                # tokenizer) stay aligned with the original source.
                consumed = src[i:end]
                nlines = consumed.count('\n')
                line += nlines
                out.append('\n' * nlines)
                i = end
                # a long comment may end mid-line; keep line_has_code as is
                continue
            else:
                # single line comment to end of line
                end = src.find('\n', j)
                if end == -1:
                    end = n
                text = src[j:end].strip()
                comments.append(Comment(text, line, inline=line_has_code))
                i = end
                continue

        # string literal: copy verbatim into output (so tokenizer sees it)
        if c in ('"', "'"):
            quote = c
            out.append(c)
            i += 1
            while i < n:
                ch = src[i]
                out.append(ch)
                if ch == '\\' and i + 1 < n:
                    out.append(src[i + 1])
                    i += 2
                    continue
                if ch == quote:
                    i += 1
                    break
                if ch == '\n':
                    line += 1
                i += 1
            line_has_code = True
            continue

        if c == '\n':
            out.append(c)
            i += 1
            line += 1
            line_has_code = False
            continue

        out.append(c)
        if not c.isspace():
            line_has_code = True
        i += 1

    return ''.join(out), comments


TOKEN_RE = re.compile(r"""
    (?P<ws>\s+)
  | (?P<num>0[xX][0-9a-fA-F]+ | (?:\d+\.\d* | \.\d+ | \d+)(?:[eE][+-]?\d+)?)
  | (?P<str>"(?:\\.|[^"\\])*" | '(?:\\.|[^'\\])*')
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)
  | (?P<punct>== | ~= | <= | >= | \.\. | [\[\]{}=,()+\-*/%<>#])
""", re.VERBOSE)


KEYWORDS_BOOL = {'true': True, 'false': False}


def tokenize(src):
    toks = []
    i = 0
    n = len(src)
    line = 1
    while i < n:
        m = TOKEN_RE.match(src, i)
        if not m:
            raise SyntaxError(f"Cannot tokenize near line {line}: {src[i:i+40]!r}")
        kind = m.lastgroup
        text = m.group()
        if kind == 'ws':
            line += text.count('\n')
            i = m.end()
            continue
        if kind == 'name':
            if text in KEYWORDS_BOOL:
                toks.append(Tok('bool', KEYWORDS_BOOL[text], i, line))
            elif text == 'nil':
                toks.append(Tok('nil', None, i, line))
            else:
                toks.append(Tok('name', text, i, line))
        elif kind == 'num':
            toks.append(Tok('num', text, i, line))
        elif kind == 'str':
            toks.append(Tok('str', text, i, line))
        else:
            toks.append(Tok('punct', text, i, line))
        line += text.count('\n')
        i = m.end()
    toks.append(Tok('eof', None, n, line))
    return toks


# --------------------------------------------------------------------------- #
# Parser -> intermediate "node" tree carrying values + metadata
# --------------------------------------------------------------------------- #
#
# Each parsed value becomes a dict node so we can attach a "comment"/type hint
# and preserve key ordering and whether a table is an array or a map.
#
#   scalar node: {"kind":"num"/"str"/"bool"/"nil"/"enum", "value":...}
#   table  node: {"kind":"table","array":bool,"entries":[ {key, keykind, value, comment} ]}
#

class Parser:
    def __init__(self, toks):
        self.toks = toks
        self.p = 0

    def peek(self):
        return self.toks[self.p]

    def next(self):
        t = self.toks[self.p]
        self.p += 1
        return t

    def expect(self, value):
        t = self.next()
        if t.value != value:
            raise SyntaxError(f"Expected {value!r} got {t.value!r} at line {t.line}")
        return t

    # ---- expression evaluation (numbers + arithmetic) --------------------- #
    def parse_value(self):
        """Parse a value: table, string, bool, nil, enum name, or numeric expr."""
        t = self.peek()
        if t.kind == 'punct' and t.value == '{':
            return self.parse_table()
        if t.kind == 'str':
            self.next()
            return {"kind": "str", "value": decode_lua_string(t.value)}
        if t.kind == 'bool':
            self.next()
            return {"kind": "bool", "value": t.value}
        if t.kind == 'nil':
            self.next()
            return {"kind": "nil", "value": None}
        # could be an enum name OR a numeric expression starting with a name
        # (no plain identifiers besides enums occur as values here). Decide by
        # whether the name is followed by an arithmetic operator.
        if t.kind == 'name':
            nxt = self.toks[self.p + 1]
            if nxt.kind == 'punct' and nxt.value in ('+', '-', '*', '/', '%'):
                return {"kind": "num", "value": self.parse_arith()}
            # indexed lookup like country.id["USA"] or Foo[1] -> resolve the
            # whole reference (e.g. country.id["USA"] -> 2) through the enum map.
            if nxt.kind == 'punct' and nxt.value == '[':
                base = t.value
                self.next()              # name
                self.next()              # [
                kt = self.next()
                if kt.kind == 'str':
                    idx = decode_lua_string(kt.value)
                elif kt.kind == 'name':
                    idx = kt.value.split('.')[-1]
                else:
                    idx = kt.value
                self.expect(']')
                return {"kind": "enum", "value": resolve_enum(base, index=idx)}
            self.next()
            return {"kind": "enum", "value": resolve_enum(t.value)}
        # numeric expression
        if (t.kind == 'num') or (t.kind == 'punct' and t.value in ('(', '-', '+')):
            return {"kind": "num", "value": self.parse_arith()}
        raise SyntaxError(f"Unexpected token {t.value!r} at line {t.line}")

    # arithmetic with + - * / % and parens, left-assoc, * / before + -
    def parse_arith(self):
        return self._add()

    def _add(self):
        v = self._mul()
        while True:
            t = self.peek()
            if t.kind == 'punct' and t.value in ('+', '-'):
                self.next()
                r = self._mul()
                v = v + r if t.value == '+' else v - r
            else:
                return v

    def _mul(self):
        v = self._unary()
        while True:
            t = self.peek()
            if t.kind == 'punct' and t.value in ('*', '/', '%'):
                self.next()
                r = self._unary()
                if t.value == '*':
                    v = v * r
                elif t.value == '/':
                    v = v / r
                else:
                    v = v % r
            else:
                return v

    def _unary(self):
        t = self.peek()
        if t.kind == 'punct' and t.value in ('-', '+'):
            self.next()
            v = self._unary()
            return -v if t.value == '-' else v
        return self._atom()

    def _atom(self):
        t = self.next()
        if t.kind == 'num':
            return parse_number(t.value)
        if t.kind == 'punct' and t.value == '(':
            v = self._add()
            self.expect(')')
            return v
        if t.kind == 'name':
            # enum used inside arithmetic (e.g. an index) - shouldn't happen for
            # numeric output; treat as error to be safe.
            raise SyntaxError(f"Identifier {t.value!r} in numeric expr at line {t.line}")
        raise SyntaxError(f"Bad atom {t.value!r} at line {t.line}")

    # ---- table ------------------------------------------------------------ #
    def parse_table(self):
        self.expect('{')
        entries = []
        array_index = 1
        is_array = True
        while True:
            t = self.peek()
            if t.kind == 'punct' and t.value == '}':
                self.next()
                break

            key = None
            keykind = None  # 'ident','enum','num','str' or None for array
            start_line = t.line

            # [ expr ] = value
            if t.kind == 'punct' and t.value == '[':
                self.next()
                kt = self.peek()
                if kt.kind == 'str':
                    self.next()
                    key = decode_lua_string(kt.value)
                    keykind = 'str'
                elif kt.kind == 'name':
                    self.next()
                    # support an indexed key like [country.id["USA"]]
                    if self.peek().kind == 'punct' and self.peek().value == '[':
                        self.next()              # [
                        it = self.next()
                        idx = decode_lua_string(it.value) if it.kind == 'str' \
                            else (it.value.split('.')[-1] if it.kind == 'name' else it.value)
                        self.expect(']')
                        key = resolve_enum(kt.value, index=idx)
                    else:
                        key = resolve_enum(kt.value)
                    keykind = 'enum'
                elif kt.kind == 'num' or (kt.kind == 'punct' and kt.value in ('-', '(')):
                    key = parse_number_expr(self)
                    keykind = 'num'
                else:
                    raise SyntaxError(f"Bad table key at line {kt.line}")
                self.expect(']')
                self.expect('=')
                is_array = False
            # ident = value
            elif t.kind == 'name' and self.toks[self.p + 1].kind == 'punct' and self.toks[self.p + 1].value == '=':
                self.next()
                self.expect('=')
                key = t.value
                keykind = 'ident'
                is_array = False
            else:
                # positional array entry
                key = array_index
                keykind = 'arrayidx'
                array_index += 1

            value = self.parse_value()
            entries.append({
                "key": key,
                "keykind": keykind,
                "value": value,
                "line": start_line,
                "endline": self.toks[self.p - 1].line,
            })

            # optional separator
            t = self.peek()
            if t.kind == 'punct' and t.value in (',', ';'):
                self.next()

        return {"kind": "table", "array": is_array, "entries": entries}


def parse_number_expr(parser):
    """Parse a (possibly arithmetic) number used as a [key]."""
    return parser.parse_arith()


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

def parse_number(text):
    if text.lower().startswith('0x'):
        return int(text, 16)
    if any(ch in text for ch in '.eE'):
        f = float(text)
        return f
    return int(text)


def decode_lua_string(tok):
    # tok includes surrounding quotes
    inner = tok[1:-1]
    return bytes(inner, "utf-8").decode("unicode_escape")


# --------------------------------------------------------------------------- #
# Enum resolution: map a Lua enum reference to the VALUE it resolves to.
#
# Enums.lua defines tables like Eras = { EARLYCOLDWAR = "Early Cold War", ... },
# Airbases = { Caucasus = { Vaziani = "Vaziani", ... } }, so a reference such as
# Eras.EARLYCOLDWAR must emit "Early Cold War", not the token "EARLYCOLDWAR".
#
# coalition.side.* and country.id[*] are DCS engine built-ins (not in Enums.lua);
# their standard numeric ids are baked in below so they resolve to numbers.
# --------------------------------------------------------------------------- #

# Standard DCS coalition side ids.
DCS_COALITION_SIDE = {"NEUTRAL": 0, "RED": 1, "BLUE": 2}

# Standard DCS country.id table (subset is fine; full standard set included so
# future countries resolve without code changes).
DCS_COUNTRY_ID = {
    "RUSSIA": 0, "UKRAINE": 1, "USA": 2, "TURKEY": 3, "UK": 4, "FRANCE": 5,
    "GERMANY": 6, "AGGRESSORS": 7, "CANADA": 8, "SPAIN": 9, "THE_NETHERLANDS": 10,
    "BELGIUM": 11, "NORWAY": 12, "DENMARK": 13, "ISRAEL": 15, "GEORGIA": 16,
    "INSURGENTS": 17, "ABKHAZIA": 18, "SOUTH_OSETIA": 19, "ITALY": 20,
    "AUSTRALIA": 21, "SWITZERLAND": 22, "AUSTRIA": 23, "BELARUS": 24,
    "BULGARIA": 25, "CHEZH_REPUBLIC": 26, "CHINA": 27, "CROATIA": 28,
    "EGYPT": 29, "FINLAND": 30, "GREECE": 31, "HUNGARY": 32, "INDIA": 33,
    "IRAN": 34, "IRAQ": 35, "JAPAN": 36, "KAZAKHSTAN": 37, "NORTH_KOREA": 38,
    "PAKISTAN": 39, "POLAND": 40, "ROMANIA": 41, "SAUDI_ARABIA": 42,
    "SERBIA": 43, "SLOVAKIA": 44, "SOUTH_KOREA": 45, "SWEDEN": 46, "SYRIA": 47,
    "YEMEN": 48, "VIETNAM": 49, "VENEZUELA": 50, "TUNISIA": 51, "THAILAND": 52,
    "SUDAN": 53, "PHILIPPINES": 54, "MOROCCO": 55, "MEXICO": 56, "MALAYSIA": 57,
    "LIBYA": 58, "JORDAN": 59, "INDONESIA": 60, "HONDURAS": 61, "ETHIOPIA": 62,
    "CHILE": 63, "BRAZIL": 64, "BAHRAIN": 65, "THAILANDB": 66, "UAE": 67,
    "UNITED_ARAB_EMIRATES": 67, "KUWAIT": 68, "QATAR": 69, "OMAN": 70,
    "LEBANON": 71, "CUBA": 72, "ECUADOR": 73, "SLOVENIA": 79,
}

# Populated from Enums.lua: dotted path (e.g. "Eras.EARLYCOLDWAR",
# "Airbases.Caucasus.Vaziani") -> resolved value.
ENUM_RESOLVER = {}


def _flatten_enum(prefix, node, out):
    """Recursively flatten a parsed Enums.lua table node into dotted paths."""
    if node["kind"] != "table":
        out[prefix] = node["value"]
        return
    for ent in node["entries"]:
        key = ent["key"]
        if ent["keykind"] in ("ident", "enum", "str"):
            path = f"{prefix}.{key}" if prefix else str(key)
        else:
            path = f"{prefix}[{key}]" if prefix else str(key)
        _flatten_enum(path, ent["value"], out)


def load_enum_resolver(enums_path):
    """Parse Enums.lua and fill ENUM_RESOLVER with dotted-path -> value, plus the
    baked DCS coalition.side / country.id maps. Safe to call with a missing
    file (then only the DCS built-ins are available)."""
    ENUM_RESOLVER.clear()
    # DCS built-ins
    for k, v in DCS_COALITION_SIDE.items():
        ENUM_RESOLVER[f"coalition.side.{k}"] = v
    for k, v in DCS_COUNTRY_ID.items():
        ENUM_RESOLVER[f"country.id.{k}"] = v
        ENUM_RESOLVER[f'country.id["{k}"]'] = v

    p = Path(enums_path)
    if not p.exists():
        return ENUM_RESOLVER
    src = p.read_text(encoding="utf-8")
    clean, _ = strip_comments(src)

    # Enums.lua may contain non-table Lua (class defs, method calls) that our
    # restricted tokenizer cannot handle. So locate each top-level
    # `Name = { ... }` block by brace matching on the cleaned text and parse
    # ONLY that block, skipping everything else.
    assign_re = re.compile(r'(?m)^(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{')
    for m in assign_re.finditer(clean):
        name = m.group("name")
        start = m.end() - 1  # at the '{'
        depth = 0
        j = start
        while j < len(clean):
            ch = clean[j]
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    break
            elif ch in ('"', "'"):
                j += 1
                while j < len(clean) and clean[j] != ch:
                    if clean[j] == '\\':
                        j += 1
                    j += 1
            j += 1
        block = clean[start:j + 1]
        try:
            toks = tokenize(block)
            node = Parser(toks).parse_table()
            _flatten_enum(name, node, ENUM_RESOLVER)
        except SyntaxError:
            continue  # not a plain enum table; skip
    return ENUM_RESOLVER


def resolve_enum(dotted, index=None):
    """Resolve a Lua enum reference to its value via ENUM_RESOLVER.
      dotted: the dotted name, e.g. 'Eras.EARLYCOLDWAR' or 'country.id'
      index : optional [index] applied to it, e.g. country.id["USA"] -> index 'USA'
    Falls back to the last token segment (the old behavior) when unknown, so
    DCS globals we have not baked in still produce a readable string."""
    if index is not None:
        # try dotted["index"] and dotted.index forms
        for key in (f'{dotted}["{index}"]', f'{dotted}.{index}'):
            if key in ENUM_RESOLVER:
                return ENUM_RESOLVER[key]
        return index  # unknown -> keep the bracket token
    if dotted in ENUM_RESOLVER:
        return ENUM_RESOLVER[dotted]
    return dotted.split('.')[-1]


def enum_token(dotted):
    """Backward-compatible name kept for the key paths; resolves through the
    enum table, falling back to the last token segment."""
    return resolve_enum(dotted)


# --------------------------------------------------------------------------- #
# Attach comments as field descriptions
# --------------------------------------------------------------------------- #

def build_comment_index(comments):
    inline = {}      # line -> text (trailing comment on that line)
    standalone = {}  # line -> [text,...] (full-line comments, possibly several)
    for c in comments:
        if c.inline:
            inline.setdefault(c.line, []).append(c.text)
        else:
            standalone.setdefault(c.line, []).append(c.text)
    return inline, standalone


TYPE_HINT_RE = re.compile(r'^\((?P<t>[^)]*)\)\s*(?P<rest>.*)$')


def annotate(node, inline, standalone):
    """Walk the value tree; for each table entry derive a 'comment' and a
    'typehint' from the inline comment on its line, or the standalone comment
    block immediately above it."""
    if node["kind"] != "table":
        return
    for ent in node["entries"]:
        desc = ""
        # 1) inline comment on the entry's DECLARATION line only. We must not
        #    scan into a table value's body (ent.line..ent.endline) or a parent
        #    table would wrongly inherit an inner field's trailing comment
        #    (e.g. era_system inheriting restricted_weapons' inline note).
        if ent["line"] in inline:
            desc = " ".join(inline[ent["line"]]).strip()
        # 2) otherwise gather standalone comments on the lines directly above
        if not desc:
            block = []
            ln = ent["line"] - 1
            while ln in standalone:
                block.insert(0, " ".join(standalone[ln]).strip())
                ln -= 1
            desc = "  ".join(block).strip()

        typehint = ""
        m = TYPE_HINT_RE.match(desc)
        if m:
            typehint = m.group("t").strip()
            desc = m.group("rest").strip()

        # A field whose comment block carries the (ignore) marker is hidden from
        # the wizard entirely (it is dropped in to_schema).
        ent["ignore"] = (typehint.lower() == "ignore")

        ent["comment"] = desc
        ent["typehint"] = typehint
        annotate(ent["value"], inline, standalone)


# --------------------------------------------------------------------------- #
# Convert node tree -> plain JSON-able "schema" the JS understands
# --------------------------------------------------------------------------- #
#
# schema node shapes:
#   {"t":"scalar","vt":"num|str|bool|nil|enum","value":...,"comment":...}
#   {"t":"map","comment":...,"fields":[ {key,keytype,comment,typehint,schema} ]}
#   {"t":"list","comment":...,"items":[ schema,... ],"itemvt":"num|str|enum|.."}
#
# "map" preserves insertion order of fields. "list" is a pure positional array.

def to_schema(node):
    if node["kind"] != "table":
        vt = node["kind"]
        return {"t": "scalar", "vt": vt, "value": node["value"]}

    if node["array"]:
        items = [to_schema(e["value"]) for e in node["entries"]]
        itemvt = None
        if items and all(it["t"] == "scalar" for it in items):
            vts = {it["vt"] for it in items}
            if len(vts) == 1:
                itemvt = vts.pop()
        return {"t": "list", "items": items, "itemvt": itemvt}

    fields = []
    for e in node["entries"]:
        if e.get("ignore"):
            continue
        fields.append({
            "key": e["key"],
            "keytype": e["keykind"],
            "comment": e.get("comment", ""),
            "typehint": e.get("typehint", ""),
            "schema": to_schema(e["value"]),
        })
    return {"t": "map", "fields": fields}


# --------------------------------------------------------------------------- #
# Top-level: find "Name = { ... }" assignments and parse each
# --------------------------------------------------------------------------- #

def section_is_ignored(decl_line, standalone):
    """True if the contiguous standalone comment block directly above a section's
    `name = {` declaration line contains an (ignore) marker."""
    ln = decl_line - 1
    while ln in standalone:
        for text in standalone[ln]:
            if re.match(r'^\(ignore\)\s*$', text.strip(), re.I):
                return True
        ln -= 1
    return False


def parse_lua(src):
    clean, comments = strip_comments(src)
    inline, standalone = build_comment_index(comments)

    # Tokenize the whole file once and find top-level `name = { ... }`
    # assignments by walking tokens at brace depth 0. This is immune to the
    # source indentation (some tables in this file are mis-indented to col 0).
    toks = tokenize(clean)

    sections = []  # (name, schema)
    i = 0
    n = len(toks)
    while i < n:
        t = toks[i]
        if t.kind == 'name' and i + 2 < n \
                and toks[i + 1].kind == 'punct' and toks[i + 1].value == '=' \
                and toks[i + 2].kind == 'punct' and toks[i + 2].value == '{':
            name = t.value
            parser = Parser(toks[i + 2:])     # start at the '{'
            node = parser.parse_table()
            annotate(node, inline, standalone)
            # advance i past this table by re-using the parser's consumed count
            i += 2 + parser.p
            # A whole top-level section can be hidden by putting (ignore) in the
            # standalone comment block directly above its `name = {` line.
            if not section_is_ignored(t.line, standalone):
                sections.append((name, to_schema(node)))
            continue
        i += 1
    return sections


# --------------------------------------------------------------------------- #
# HTML emission
# --------------------------------------------------------------------------- #

HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Crossfire Config Wizard</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<style>
  @import url('https://fonts.googleapis.com/css?family=Source+Sans+Pro:400,700');
  :root {
    --bg:#ffffff; --panel:#ffffff; --panel2:#ffffff; --line:#000000;
    --text:#000000; --muted:#555555; --accent:#000000;
    --zebra:#EEEEEE; --num:#000000; --str:#000000;
  }
  * { box-sizing:border-box; }
  body {
    margin:0; background:var(--bg); color:var(--text);
    font-family:'Source Sans Pro', sans-serif;
    font-size:14px; line-height:1.45;
  }
  header {
    position:sticky; top:0; z-index:10; background:#ffffff;
    border-bottom:1px solid #000000; padding:12px 18px;
    display:flex; align-items:center; gap:12px; flex-wrap:wrap;
  }
  header h1 { font-size:18px; margin:0; font-weight:700; }
  header .spacer { flex:1; }
  header .ver { color:var(--muted); font-size:12px; }
  button {
    background:#ffffff; color:#000000; border:1px solid #000000; border-radius:2px;
    padding:5px 15px; font-size:13px; font-weight:400; cursor:pointer;
    text-align:center; display:inline-block;
  }
  button:hover { filter:brightness(95%); }
  button.small { padding:2px 8px; font-size:12px; }
  #search {
    background:#ffffff; border:1px solid #000000; color:#000000;
    border-radius:2px; padding:6px 10px; font-size:13px; width:240px;
    font-family:inherit;
  }
  main { max-width:1000px; margin:0 auto; padding:18px; }
  .section { margin-bottom:22px; }
  .section > .sec-title {
    font-size:16px; font-weight:700; color:#000000;
    border-bottom:2px solid #000000; padding-bottom:6px; margin-bottom:8px;
  }
  details.node { border-left:1px solid #000000; margin:4px 0; padding-left:10px; }
  details.node > summary {
    cursor:pointer; padding:4px 0; font-weight:700; list-style:none;
    display:flex; align-items:center; gap:8px;
  }
  details.node > summary::-webkit-details-marker { display:none; }
  details.node > summary::before {
    content:"\25B8"; color:#000000; font-size:11px; transition:transform .1s;
  }
  details.node[open] > summary::before { transform:rotate(90deg); }
  .keyname { color:#000000; }
  .badge {
    font-size:11px; color:var(--muted); background:#ffffff;
    border:1px solid #000000; border-radius:10px; padding:0 7px;
  }
  .row {
    display:flex; align-items:flex-start; gap:10px; padding:5px 8px;
  }
  .row:nth-child(odd) { background-color:var(--zebra); }
  .row .label { width:300px; min-width:300px; }
  .row .label .k { font-weight:700; word-break:break-word; }
  .row .label .help { color:var(--muted); font-size:12px; margin-top:1px; }
  .row .label .help .th { color:#000000; font-weight:700; }
  .row .control { flex:1; display:flex; align-items:center; gap:8px; flex-wrap:wrap; }
  input[type=text], input[type=number], select {
    background:#ffffff; border:1px solid #000000; color:#000000;
    border-radius:2px; padding:5px 8px; font-size:13px; min-width:120px;
    font-family:inherit;
  }
  input[type=number] { color:var(--num); }
  input.str { color:var(--str); }
  input:focus, select:focus { outline:2px solid #000000; }
  .toggle { display:inline-flex; align-items:center; gap:6px; cursor:pointer; }
  .listbox {
    width:100%; background:#ffffff; border:1px solid #000000;
    border-radius:2px; padding:8px;
  }
  .listrow { display:flex; gap:6px; align-items:center; margin-bottom:5px; }
  .listrow .idx { color:var(--muted); width:26px; text-align:right; font-size:12px; }
  .listrow input { flex:1; }
  .nested { margin-top:4px; }
  .hidden { display:none !important; }
  .color-swatch { width:22px; height:22px; border-radius:2px; border:1px solid #000000; }
  .note { color:var(--muted); font-size:12px; margin:6px 0 14px; }
  footer { text-align:center; color:var(--muted); font-size:12px; padding:24px; }
  .pill { font-size:11px; padding:1px 6px; border-radius:8px; background:#ffffff; color:var(--muted); border:1px solid #000000; }
</style>
</head>
<body>
<header>
  <h1>Crossfire Config Wizard</h1>
  <span class="ver">__VERSION__</span>
  <input id="search" type="text" placeholder="Filter fields&hellip;">
  <span class="spacer"></span>
  <button class="ghost" id="expandAll">Expand all</button>
  <button class="ghost" id="collapseAll">Collapse all</button>
  <button class="ghost" id="loadJson">Load config.json</button>
  <button id="download">Download config.json</button>
  <input id="fileInput" type="file" accept="application/json,.json" class="hidden">
</header>
<main id="app"></main>
<script id="schema-data" type="application/json">__SCHEMA__</script>
<script>
"use strict";
const SCHEMA = JSON.parse(document.getElementById('schema-data').textContent);

function el(tag, cls, txt){
  const e = document.createElement(tag);
  if(cls) e.className = cls;
  if(txt!=null) e.textContent = txt;
  return e;
}

function keyLabel(k){ return (typeof k === 'number') ? '['+k+']' : k; }

function scalarControl(node){
  const wrap = el('div','control');
  if(node.vt === 'bool'){
    const lbl = el('label','toggle');
    const cb = el('input'); cb.type='checkbox'; cb.checked = !!node.value;
    cb.addEventListener('change', ()=> node.value = cb.checked);
    lbl.appendChild(cb); lbl.appendChild(el('span',null, 'enabled'));
    wrap.appendChild(lbl);
  } else if(node.vt === 'num'){
    const inp = el('input'); inp.type='number'; inp.step='any';
    inp.value = node.value;
    inp.addEventListener('input', ()=>{
      const v = inp.value.trim();
      node.value = (v==='') ? null : Number(v);
    });
    wrap.appendChild(inp);
  } else if(node.vt === 'enum'){
    const inp = el('input','str'); inp.type='text'; inp.value = node.value;
    inp.title = 'enum token (stored as string)';
    inp.addEventListener('input', ()=> node.value = inp.value);
    wrap.appendChild(inp);
    wrap.appendChild(el('span','pill','enum'));
  } else if(node.vt === 'nil'){
    const inp = el('input','str'); inp.type='text'; inp.value='';
    inp.placeholder='(nil)';
    inp.addEventListener('input', ()=>{
      node.value = inp.value===''? null : inp.value;
      node.vt = inp.value===''? 'nil':'str';
    });
    wrap.appendChild(inp);
  } else { // str
    const inp = el('input','str'); inp.type='text'; inp.value = node.value ?? '';
    inp.addEventListener('input', ()=> node.value = inp.value);
    wrap.appendChild(inp);
  }
  return wrap;
}

function isColorList(node){
  if(node.t!=='list') return false;
  if(node.items.length<3 || node.items.length>4) return false;
  return node.items.every(it=> it.t==='scalar' && it.vt==='num' && it.value>=0 && it.value<=1);
}
function colorControl(node){
  const wrap = el('div','control');
  const toHex = v => { const n=Math.round((v||0)*255); return n.toString(16).padStart(2,'0'); };
  const sw = el('div','color-swatch');
  const picker = el('input'); picker.type='color';
  function refresh(){
    const [r,g,b] = node.items;
    const hex = '#'+toHex(r.value)+toHex(g.value)+toHex(b.value);
    sw.style.background = hex; picker.value = hex;
  }
  picker.addEventListener('input', ()=>{
    const h = picker.value;
    node.items[0].value = parseInt(h.substr(1,2),16)/255;
    node.items[1].value = parseInt(h.substr(3,2),16)/255;
    node.items[2].value = parseInt(h.substr(5,2),16)/255;
    refresh(); syncNums();
  });
  wrap.appendChild(picker); wrap.appendChild(sw);

  const numInputs = [];
  const labels = ['R','G','B','A'];
  node.items.forEach((it,i)=>{
    const c = el('span',null, labels[i]+':');
    c.style.color='var(--muted)'; c.style.fontSize='12px';
    const inp = el('input'); inp.type='number'; inp.step='0.01'; inp.min='0'; inp.max='1';
    inp.value = it.value; inp.style.width='70px';
    inp.addEventListener('input', ()=>{ it.value=Number(inp.value); refresh(); });
    numInputs.push(inp);
    wrap.appendChild(c); wrap.appendChild(inp);
  });
  function syncNums(){ node.items.forEach((it,i)=> numInputs[i].value = it.value); }
  refresh();
  return wrap;
}

function listControl(node){
  if(isColorList(node)) return colorControl(node);
  // list of nested tables -> render each as a node block
  const allScalar = node.items.every(it=> it.t==='scalar');
  if(!allScalar){
    const box = el('div','nested');
    node.items.forEach((it,i)=>{
      box.appendChild(renderNode('['+(i+1)+']', it, '', ''));
    });
    return box;
  }
  const box = el('div','listbox');
  function rebuild(){
    box.innerHTML='';
    node.items.forEach((it,i)=>{
      const r = el('div','listrow');
      r.appendChild(el('div','idx', (i+1)+'.'));
      const inp = el('input');
      if(it.vt==='num'){ inp.type='number'; inp.step='any'; }
      else { inp.type='text'; inp.className='str'; }
      inp.value = it.value ?? '';
      inp.addEventListener('input', ()=>{
        it.value = it.vt==='num' ? Number(inp.value) : inp.value;
      });
      r.appendChild(inp);
      const del = el('button','ghost small','✕');
      del.addEventListener('click', ()=>{ node.items.splice(i,1); rebuild(); });
      r.appendChild(del);
      box.appendChild(r);
    });
    const add = el('button','ghost small','+ add');
    add.addEventListener('click', ()=>{
      const vt = node.itemvt || (node.items[0] && node.items[0].vt) || 'str';
      node.items.push({t:'scalar', vt:vt, value: vt==='num'?0:''});
      rebuild();
    });
    box.appendChild(add);
  }
  rebuild();
  return box;
}

function renderRow(key, node, comment, typehint){
  const row = el('div','row');
  row.dataset.key = (''+key).toLowerCase();
  row.dataset.help = ((comment||'')+' '+(typehint||'')).toLowerCase();
  const label = el('div','label');
  label.appendChild(el('div','k', keyLabel(key)));
  if(comment || typehint){
    const h = el('div','help');
    if(typehint){ const t=el('span','th','('+typehint+') '); h.appendChild(t); }
    h.appendChild(document.createTextNode(comment||''));
    label.appendChild(h);
  }
  row.appendChild(label);
  let control;
  if(node.t==='scalar') control = scalarControl(node);
  else if(node.t==='list') control = listControl(node);
  row.appendChild(control);
  return row;
}

function renderNode(key, node, comment, typehint){
  if(node.t==='map'){
    const d = el('details','node'); d.open = false;
    const s = el('summary');
    s.appendChild(el('span','keyname', keyLabel(key)));
    s.appendChild(el('span','badge', node.fields.length+' fields'));
    if(comment){ const c=el('span','help'); c.style.color='var(--muted)'; c.style.fontWeight='400'; c.textContent='— '+comment; s.appendChild(c);}
    d.appendChild(s);
    const body = el('div');
    node.fields.forEach(f=>{
      body.appendChild(renderNode(f.key, f.schema, f.comment, f.typehint));
    });
    d.appendChild(body);
    return d;
  }
  return renderRow(key, node, comment, typehint);
}

const app = document.getElementById('app');
SCHEMA.sections.forEach(([name, schema])=>{
  const sec = el('div','section');
  sec.appendChild(el('div','sec-title', name));
  if(schema.t==='map'){
    schema.fields.forEach(f=>{
      sec.appendChild(renderNode(f.key, f.schema, f.comment, f.typehint));
    });
  } else {
    sec.appendChild(renderNode(name, schema, '', ''));
  }
  app.appendChild(sec);
});

function serialize(node){
  if(node.t==='scalar'){
    if(node.vt==='nil') return null;
    if(node.vt==='num') return node.value;
    return node.value;
  }
  if(node.t==='list'){
    return node.items.map(serialize);
  }
  const o = {};
  node.fields.forEach(f=>{ o[f.key] = serialize(f.schema); });
  return o;
}

function buildConfig(){
  const out = {};
  SCHEMA.sections.forEach(([name, schema])=>{ out[name] = serialize(schema); });
  return out;
}

document.getElementById('download').addEventListener('click', ()=>{
  const data = JSON.stringify(buildConfig(), null, 2);
  const blob = new Blob([data], {type:'application/json'});
  const url = URL.createObjectURL(blob);
  const a = el('a'); a.href=url; a.download='config.json';
  document.body.appendChild(a); a.click(); a.remove();
  URL.revokeObjectURL(url);
});

function applyValues(node, val){
  if(node.t==='scalar'){
    if(val===null||val===undefined){ node.value=null; if(node.vt!=='nil') node.value=node.value; return; }
    if(typeof val==='boolean'){ node.vt='bool'; node.value=val; }
    else if(typeof val==='number'){ node.vt='num'; node.value=val; }
    else { if(node.vt!=='enum') node.vt='str'; node.value=val; }
    return;
  }
  if(node.t==='list'){
    if(!Array.isArray(val)) return;
    // resize to match
    const proto = node.items[0] || {t:'scalar',vt:node.itemvt||'str',value:''};
    node.items = val.map(v=>{
      const it = JSON.parse(JSON.stringify(proto));
      applyValues(it, v);
      return it;
    });
    return;
  }
  if(node.t==='map' && val && typeof val==='object'){
    node.fields.forEach(f=>{
      if(Object.prototype.hasOwnProperty.call(val, f.key)){
        applyValues(f.schema, val[f.key]);
      }
    });
  }
}
document.getElementById('loadJson').addEventListener('click', ()=> document.getElementById('fileInput').click());
document.getElementById('fileInput').addEventListener('change', (e)=>{
  const file = e.target.files[0]; if(!file) return;
  const fr = new FileReader();
  fr.onload = ()=>{
    try{
      const obj = JSON.parse(fr.result);
      SCHEMA.sections.forEach(([name, schema])=>{
        if(Object.prototype.hasOwnProperty.call(obj, name)) applyValues(schema, obj[name]);
      });
      app.innerHTML='';
      SCHEMA.sections.forEach(([name, schema])=>{
        const sec = el('div','section');
        sec.appendChild(el('div','sec-title', name));
        if(schema.t==='map'){ schema.fields.forEach(f=> sec.appendChild(renderNode(f.key, f.schema, f.comment, f.typehint))); }
        else sec.appendChild(renderNode(name, schema,'',''));
        app.appendChild(sec);
      });
      alert('Loaded '+file.name);
    }catch(err){ alert('Could not parse JSON: '+err.message); }
  };
  fr.readAsText(file);
});

document.getElementById('expandAll').addEventListener('click', ()=>
  document.querySelectorAll('details.node').forEach(d=> d.open=true));
document.getElementById('collapseAll').addEventListener('click', ()=>
  document.querySelectorAll('details.node').forEach(d=> d.open=false));

document.getElementById('search').addEventListener('input', (e)=>{
  const q = e.target.value.trim().toLowerCase();
  const rows = document.querySelectorAll('.row');
  if(!q){
    rows.forEach(r=> r.classList.remove('hidden'));
    document.querySelectorAll('details.node').forEach(d=>{ d.classList.remove('hidden'); d.open=false; });
    return;
  }
  rows.forEach(r=>{
    const hit = r.dataset.key.includes(q) || r.dataset.help.includes(q);
    r.classList.toggle('hidden', !hit);
  });
  document.querySelectorAll('details.node').forEach(d=>{
    const visible = d.querySelector('.row:not(.hidden)');
    d.classList.toggle('hidden', !visible);
    if(visible) d.open = true;
  });
});
</script>
</body>
</html>
"""


def emit_html(sections, version_label):
    payload = {"sections": sections}
    schema_json = json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
    # protect against an accidental </script> inside string data
    schema_json = schema_json.replace('</', '<\\/')
    html = HTML_TEMPLATE.replace('__SCHEMA__', schema_json)
    html = html.replace('__VERSION__', version_label)
    return html


def main(argv):
    src_path = Path(argv[1]) if len(argv) > 1 else Path("config.lua")
    out_path = Path(argv[2]) if len(argv) > 2 else Path("config_wizard.html")
    enums_path = Path(argv[3]) if len(argv) > 3 else (src_path.parent / "Enums.lua")

    if not src_path.exists():
        print(f"error: {src_path} not found", file=sys.stderr)
        return 1

    # Load enum definitions so references like Eras.EARLYCOLDWAR resolve to their
    # value ("Early Cold War") rather than the bare token.
    load_enum_resolver(enums_path)
    if not Path(enums_path).exists():
        print(f"warning: {enums_path} not found - enum values will fall back to "
              f"their token names", file=sys.stderr)

    src = src_path.read_text(encoding="utf-8")
    sections = parse_lua(src)

    version_label = ""
    for name, schema in sections:
        if name == "Config" and schema["t"] == "map":
            for f in schema["fields"]:
                if f["key"] == "_config_file_version":
                    version_label = f"config v{f['schema'].get('value')}"
            break

    html = emit_html(sections, version_label or "")
    out_path.write_text(html, encoding="utf-8")

    n_sections = len(sections)
    print(f"Parsed {src_path} -> {n_sections} section(s): " +
          ", ".join(n for n, _ in sections))
    print(f"Wrote {out_path}  ({out_path.stat().st_size//1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
