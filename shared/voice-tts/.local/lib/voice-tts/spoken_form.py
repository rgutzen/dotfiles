"""spoken_form -- turn written markdown into text a voice can read.

WHY. Stripping markup gets most of the way; what it leaves is what makes an
agent's answer unlistenable: a table read as cells, a path read slash by slash,
a hash read letter by letter. This module classifies each block and rewrites it
by rules into a short spoken description. Pure functions, no I/O, so `say`, the
phone's `psay` and the tests share it (dev/voice-out/SPECS.md N1, decision 12).

Two promises, both tested on every fixture:

- **Never silent.** Every block yields a sentence. A code block is named and
  counted, not dropped.
- **Never a changed number.** Every run of digits in the output occurs in the
  input. Counts the rules add (rows, lines) are spelled out in words, and an
  identifier that is kept is kept verbatim.

    blocks = classify(text)      # [Block(kind, text, lang, rewrite)]
    speech = spoken(text)        # one string, one block per line

`Block.rewrite` marks the blocks a local model may describe better than rules
(N3). Code and diffs are never handed over: they are described, not retold.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urlparse

KINDS = ("prose", "bullets", "table", "code", "diff", "paths", "diagram",
         "heading", "url", "token", "frontmatter")
REWRITE_KINDS = {"table", "diagram"}

LANGUAGES = {
    "py": "Python", "python": "Python", "python3": "Python",
    "sh": "shell", "bash": "shell", "zsh": "shell", "shell": "shell", "console": "shell",
    "js": "JavaScript", "javascript": "JavaScript", "ts": "TypeScript",
    "typescript": "TypeScript", "json": "JSON", "jsonl": "JSON", "yaml": "YAML",
    "yml": "YAML", "toml": "TOML", "md": "Markdown", "markdown": "Markdown",
    "lua": "Lua", "rust": "Rust", "rs": "Rust", "go": "Go", "c": "C", "cpp": "C++",
    "sql": "SQL", "html": "HTML", "css": "CSS", "ini": "INI", "nix": "Nix",
}

DIAGRAMS = (
    ("flowchart", "a flowchart"), ("graph", "a flowchart"),
    ("sequenceDiagram", "a sequence diagram"), ("classDiagram", "a class diagram"),
    ("stateDiagram", "a state diagram"), ("erDiagram", "an entity diagram"),
    ("gantt", "a Gantt chart"), ("pie", "a pie chart"), ("mindmap", "a mind map"),
    ("timeline", "a timeline"), ("journey", "a journey diagram"),
)

BOX = re.compile(r"[\u2500-\u257f\u2580-\u259f]")


@dataclass
class Block:
    kind: str
    text: str
    lang: str = ""

    @property
    def rewrite(self) -> bool:
        return self.kind in REWRITE_KINDS


# ------------------------------------------------------------------ the legacy pass


def strip_unspoken(text: str) -> str:
    """The stripping `say` did before this module: drop what cannot be spoken.

    Kept verbatim, so `say --spoken-form off` (N4) and the phone's fallback
    behave as they did. It is silent on code and tables, which is why
    `spoken()` exists.
    """
    text = re.sub(r"```.*?```", "", text, flags=re.S)          # fenced code
    text = re.sub(r"`([^`]*)`", r"\1", text)                    # inline code
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)            # images
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)        # links -> label
    text = re.sub(r"https?://\S+", "", text)                    # bare urls
    text = re.sub(r"^\s*\|.*$", "", text, flags=re.M)            # table rows (truncated too)
    text = re.sub(r"^.*\|.*\|.*$", "", text, flags=re.M)         # table rows
    text = re.sub(r"^\s*[-=]{3,}\s*$", "", text, flags=re.M)      # rules
    text = re.sub(r"^\s{0,3}#{1,6}\s*", "", text, flags=re.M)   # headings
    text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.M)        # bullets
    text = re.sub(r"^\s*\d+[.)]\s+", "", text, flags=re.M)      # numbered lists
    text = re.sub(r"[*_]{1,2}([^*_]+)[*_]{1,2}", r"\1", text)   # emphasis
    text = re.sub(r"[\u2014\u2013]", ", ", text)                 # em/en dash -> pause
    text = re.sub(r"[\u00b7\u2022\u25aa\u25ab\u2581-\u2588\u25cf\u25cb]", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


# ------------------------------------------------------------------ numbers in words

_ONES = ("zero one two three four five six seven eight nine ten eleven twelve "
         "thirteen fourteen fifteen sixteen seventeen eighteen nineteen").split()
_TENS = "_ _ twenty thirty forty fifty sixty seventy eighty ninety".split()


def words(n: int) -> str:
    """A count the rules add, in words, so no new digit enters the output."""
    if n < 20:
        return _ONES[n]
    if n < 100:
        return _TENS[n // 10] + ("" if n % 10 == 0 else "-" + _ONES[n % 10])
    if n < 1000:
        rest = n % 100
        return _ONES[n // 100] + " hundred" + ("" if rest == 0 else " and " + words(rest))
    if n < 1_000_000:
        rest = n % 1000
        return words(n // 1000) + " thousand" + ("" if rest == 0 else " " + words(rest))
    return "more than a million"


def counted(n: int, noun: str, plural: str | None = None) -> str:
    return f"{words(n)} {noun if n == 1 else (plural or noun + 's')}"


_MONTHS = ("January February March April May June July August September October "
           "November December").split()


def ordinal(n: int) -> str:
    """28 -> "28th": the digits stay, the suffix is what a voice says."""
    suffix = "th" if 10 <= n % 100 <= 20 else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
    return f"{n}{suffix}"


def say_date(m: re.Match) -> str:
    year, month, day = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if not (1 <= month <= 12 and 1 <= day <= 31):
        return m.group(0)
    return f"{_MONTHS[month - 1]} {ordinal(day)} {year}"


DATE = re.compile(r"(?<![\w-])(\d{4})-(\d{2})-(\d{2})(?!\d)")
ID_RANGE = re.compile(r"(?<![\w-])([A-Z]+\d+[a-z]?)-([A-Z]+\d+[a-z]?)(?![\w-])")   # M0-M4
NUM_RANGE = re.compile(r"(?<![\w.-])(\d{1,3})-(\d{1,3})(?![\w.-])")                # 1-2
WORD_HYPHEN = re.compile(r"(?<![\w-])([A-Za-z]+(?:-[A-Za-z]+)+)(?![\w-])")         # per-item


def spoken_words(text: str) -> str:
    """Dates, ranges and hyphens as a voice says them; digits are kept.

    A hyphen inside a word of letters is read as a space ("per item"). A word
    that holds a digit or an underscore is an identifier and keeps its hyphens.
    """
    text = DATE.sub(say_date, text)
    text = ID_RANGE.sub(r"\1 to \2", text)
    text = NUM_RANGE.sub(r"\1 to \2", text)
    text = WORD_HYPHEN.sub(lambda m: m.group(1).replace("-", " "), text)
    text = re.sub(r"(?<![\w-])vs\.?(?=\s)", "versus", text)
    text = re.sub(r"(?<![\w/.])(\d+)/(\d+)(?![\w/.])", r"\1 of \2", text)   # 12/12 done
    text = re.sub(r"\u00a7\s*", "section ", text)
    return text


def listed(items: list[str]) -> str:
    """a, b and c"""
    if len(items) <= 1:
        return "".join(items)
    return ", ".join(items[:-1]) + " and " + items[-1]


# ------------------------------------------------------------------ tokens

_SEG = r"(?:[\w.@+*$-]|\{[^}\s/]*\}|<[\w-]+>)+"
PATH = re.compile(rf"(?<![\w/:.~])((?:~|\.{{1,2}})?/?(?:{_SEG}/)+(?:{_SEG})?/?)(?![\w/])")
URL = re.compile(r"<?(https?://[^\s<>)\]]+)>?")
HEX = re.compile(r"^[0-9a-fA-F]{12,}$")
RUN = re.compile(r"[A-Za-z0-9]{16,}")


def is_path(tok: str) -> bool:
    if "/" not in tok or "://" in tok:
        return False
    core = tok.strip("/")
    segs = [s for s in core.split("/") if s]
    if not segs or all(s.isdigit() for s in segs):
        return False
    if tok.startswith(("~/", "/", "./", "../")) or tok.endswith("/"):
        return True
    if re.search(r"\.[A-Za-z][\w]{0,5}$", segs[-1]):
        return True
    return len(segs) >= 3 and any(len(s) > 3 for s in segs)


def is_long_token(tok: str) -> bool:
    """A hash, a key or a uuid: text whose letters carry no words."""
    tok = tok.strip(".,;:()[]'\"")
    if HEX.match(tok) and re.search(r"\d", tok) and re.search(r"[a-fA-F]", tok):
        return True
    for run in RUN.findall(tok):
        if len(re.findall(r"\d", run)) >= 3 and len(re.findall(r"[A-Za-z]", run)) >= 3:
            return True
    return False


FILE_KINDS = {
    "md": "markdown", "py": "Python", "sh": "shell", "ts": "TypeScript",
    "js": "JavaScript", "json": "JSON", "jsonl": "JSON lines", "yaml": "YAML",
    "yml": "YAML", "toml": "TOML", "lua": "Lua", "txt": "text", "csv": "CSV",
    "html": "HTML", "svg": "SVG", "png": "PNG", "wav": "WAV", "onnx": "ONNX",
    "service": "unit", "timer": "timer unit", "env": "env", "log": "log",
}
FILE_NAME = re.compile(r"(?<![\w/.~-])([\w][\w.-]*?)\.(%s)(?![\w/-])" % "|".join(FILE_KINDS))


def say_file(name: str) -> str:
    """`DATA-ARCHITECTURE.md` -> "DATA-ARCHITECTURE markdown file"."""
    m = re.fullmatch(r"(.+?)\.(%s)" % "|".join(FILE_KINDS), name)
    if not m:
        return spoken_words(name)
    return f"{spoken_words(m.group(1))} {FILE_KINDS[m.group(2)]} file"


def say_path(tok: str) -> str:
    """The name, then where it lives, outermost folder first.

        ~/.local/bin/say        -> "say in local bin"
        memory/knowledge/       -> "the folder knowledge in memory"
        dev/<track>/SPECS.md    -> "SPECS markdown file in dev tracks"
    """
    folder = tok.endswith("/")
    tok = re.sub(r"\{([^}]*)\}", lambda m: " or ".join(m.group(1).split(",")), tok)
    tok = re.sub(r"<([\w-]+)>", r"\1s", tok)             # a placeholder is "any of them"
    segs = [s for s in tok.rstrip("/").split("/") if s not in ("", "~", ".", "..")]
    segs = [s.lstrip(".$") or s for s in segs if s != "*" and s != "**"]
    if not segs:
        return "a path"
    base, parent = segs[-1], [spoken_words(p) for p in segs[:-1][-2:]]
    name = f"the folder {spoken_words(base)}" if folder else say_file(base)
    return f"{name} in {' '.join(parent)}" if parent else name


def path_name(tok: str) -> str:
    """Only the name part of `say_path`."""
    return say_path(tok).split(" in ")[0]


def say_url(url: str) -> str:
    host = urlparse(url).netloc or url
    return "a link to " + re.sub(r"^www\.", "", host.split("@")[-1])


# ------------------------------------------------------------------ inline


def inline(text: str) -> str:
    """Rewrite the spans inside a prose line; the words around them stay."""
    held: list[str] = []

    def hold(s: str) -> str:
        held.append(s)
        return f"\x00{len(held) - 1}\x00"

    def token(s: str) -> str:
        s = s.strip()
        if re.search(r"\s", s):          # a command or an expression: read as written
            return s
        if URL.fullmatch(s):
            return say_url(s)
        if is_path(s) or ("/" in s and re.fullmatch(r"[\w.~/-]+", s)):  # in code, a slash is a path
            return say_path(s)
        if FILE_NAME.fullmatch(s):
            return say_file(s)
        if is_long_token(s):
            return "a long identifier"
        return s

    def reference(m: re.Match) -> str:
        """A parenthesis that holds only a pointer: said as an aside, with pauses."""
        return hold(f"; in parentheses {m.group(1)};")

    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    text = re.sub(r"^\s{0,3}>\s?", "", text, flags=re.M)                      # quotes
    text = re.sub(r"`([^`]+)`", lambda m: hold(token(m.group(1))), text)       # code spans
    text = re.sub(r"!\[([^\]]*)\]\([^)]*\)",
                  lambda m: hold("an image" + (f", {m.group(1)}" if m.group(1) else "")), text)
    text = re.sub(r"\[\[([^\]|]+)\|([^\]]+)\]\]", r"\2", text)               # [[leaf|label]]
    text = re.sub(r"\(\s*\[\[([^\]]+)\]\]\s*\)", reference, text)                # ([[leaf]])
    text = re.sub(r"\[\[([^\]]+)\]\]", r"\1", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)                      # links -> label
    text = URL.sub(lambda m: hold(say_url(m.group(1))), text)
    def path(m: re.Match) -> str:
        tok, end = re.match(r"(.*?)([.,;:]*)$", m.group(1)).groups()   # a full stop is not the path's
        return hold(say_path(tok)) + end if is_path(tok) else m.group(1)

    text = PATH.sub(path, text)
    text = FILE_NAME.sub(lambda m: hold(say_file(m.group(0))), text)
    text = re.sub(r"\S+", lambda m: hold("a long identifier") if is_long_token(m.group(0))
                  else m.group(0), text)
    text = spoken_words(text)
    text = re.sub(r"<br\s*/?>", ", ", text)
    text = re.sub(r"</?[a-zA-Z][^>]*>", "", text)
    text = re.sub(r"(?<!\w)(\*\*|__|\*|_)(?=\S)(.+?)(?<=\S)\1(?!\w)", r"\2", text,
                  flags=re.S)                                                # emphasis, not a_b
    text = re.sub(r"(?<=[\w\x00])\s*\u2013\s*(?=[\w\x00])", " to ", text)        # V1–V2
    text = re.sub(r"\s*[\u2014\u2013]\s*", ", ", text)                        # dash -> pause
    text = re.sub(r"\s*(?:\u2192|->|=>)\s*", " to ", text)
    text = re.sub(r"\s*\u2190\s*", " from ", text)
    text = re.sub(r"\u2265\s*", "at least ", text)
    text = re.sub(r"\u2264\s*", "at most ", text)
    text = re.sub(r"(?<!\w)~\s*(?=\d)", "about ", text)
    text = re.sub(r"(?<=\d)\s*\u00d7\s*(?=\d)", " times ", text)
    text = re.sub(r"(?<=\d)\u00d7", " times", text)                           # 2.1×
    text = text.replace("\u2705", "yes").replace("\u274c", "no")
    text = re.sub(r"\s*[\u00b7\u2022]\s*", ", ", text)                        # · separators
    text = re.sub(r"[\u25aa\u25ab\u2581-\u2588\u25cf\u25cb\u2591-\u2593]", " ", text)
    text = re.sub(r"\x00(\d+)\x00", lambda m: held[int(m.group(1))], text)
    text = re.sub(r"\s+", " ", text).strip()
    text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    text = re.sub(r"([,;:])(\s*[,;:])+", r"\1", text)
    text = re.sub(r";\s*([.!?])", r"\1", text)
    return text.strip(" ,;")


def sentence(text: str) -> str:
    text = text.rstrip()
    if not text:
        return text
    if text[-1] in ".!?" or re.search(r"[.!?][\"')\u201d]+$", text):
        return text
    if text[-1] in ":;,":
        text = text[:-1]
    return text + "."


# ------------------------------------------------------------------ classifier

FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})\s*([\w+-]*)")
BULLET = re.compile(r"^(\s*)(?:[-*+]|\d+[.)])\s+(.*)$")
TABLE_SEP = re.compile(r"^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$")
HEADING = re.compile(r"^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$")
RULE = re.compile(r"^\s{0,3}([-*_=])(\s*\1){2,}\s*$")
DIFF_START = re.compile(r"^(diff --git |--- [a-z]/|\+\+\+ [a-z]/|@@ -\d)")


def classify(text: str) -> list[Block]:
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)   # unrendered: the eye sees nothing either
    lines = text.replace("\r\n", "\n").split("\n")
    blocks: list[Block] = []
    i, n = 0, len(lines)

    if lines and lines[0].strip() == "---":                     # front matter
        for j in range(1, n):
            if lines[j].strip() == "---":
                blocks.append(Block("frontmatter", "\n".join(lines[1:j])))
                i = j + 1
                break

    while i < n:
        line = lines[i]
        if not line.strip() or RULE.match(line):
            i += 1
            continue

        fence = FENCE.match(line)
        if fence:
            mark, lang = fence.group(1), fence.group(2).lower()
            j = i + 1
            while j < n and not lines[j].strip().startswith(mark):
                j += 1
            body = "\n".join(lines[i + 1:j])
            blocks.append(_fenced(body, lang))
            i = j + 1
            continue

        heading = HEADING.match(line)
        if heading:
            blocks.append(Block("heading", heading.group(1)))
            i += 1
            continue

        if line.lstrip().startswith("|"):
            j = i
            while j < n and lines[j].lstrip().startswith("|"):
                j += 1
            blocks.append(Block("table", "\n".join(lines[i:j])))
            i = j
            continue

        if DIFF_START.match(line):
            j = i
            while j < n and lines[j] != "":       # a blank context line is " "
                j += 1
            blocks.append(Block("diff", "\n".join(lines[i:j])))
            i = j
            continue

        if BULLET.match(line):
            j = i + 1
            while j < n and (BULLET.match(lines[j]) or
                             (lines[j].strip() and lines[j].startswith((" ", "\t")))):
                j += 1
            body = "\n".join(lines[i:j])
            blocks.append(Block("paths" if _is_path_list(_items(body)) else "bullets", body))
            i = j
            continue

        j = i
        while (j < n and lines[j].strip() and not FENCE.match(lines[j])
               and not HEADING.match(lines[j]) and not lines[j].lstrip().startswith("|")
               and not (j > i and BULLET.match(lines[j]))):
            j += 1
        body = "\n".join(lines[i:j])
        blocks.append(_paragraph(body))
        i = j
    return blocks


def _fenced(body: str, lang: str) -> Block:
    rows = [l for l in body.split("\n") if l.strip()]
    if lang == "mermaid":
        return Block("diagram", body, lang)
    if lang in ("diff", "patch") or (rows and not lang and _looks_like_diff(rows)):
        return Block("diff", body, lang)
    if not lang or lang in ("text", "txt", "plain"):
        if rows and sum(bool(BOX.search(r)) for r in rows) >= max(2, len(rows) // 3):
            return Block("diagram", body, lang)
        if _is_path_list(rows):
            return Block("paths", body, lang)
    return Block("code", body, lang)


def _paragraph(body: str) -> Block:
    one = body.strip()
    if URL.fullmatch(one):
        return Block("url", one)
    if " " not in one and is_long_token(one):
        return Block("token", one)
    rows = [l for l in body.split("\n") if l.strip()]
    if len(rows) >= 2 and sum(bool(BOX.search(r)) for r in rows) >= len(rows) // 2 + 1:
        return Block("diagram", body)
    if _is_path_list(rows) and len(rows) >= 1 and all(_lead_path(r) for r in rows):
        return Block("paths", body)
    return Block("prose", body)


def _looks_like_diff(rows: list[str]) -> bool:
    if any(r.startswith("@@ ") for r in rows) or rows[0].startswith("diff --git"):
        return True
    return False


def _items(body: str) -> list[str]:
    out = []
    for line in body.split("\n"):
        m = BULLET.match(line)
        if m:
            out.append(re.sub(r"^\[[ xX]\]\s+", "", m.group(2)))   # task-list box
        elif out and line.strip():
            out[-1] += " " + line.strip()
    return out


def _lead_path(row: str) -> str:
    """The path a row starts with, ignoring backticks: '`a/b.md` -- note' -> 'a/b.md'."""
    first = row.strip().split()[0] if row.strip() else ""
    first = first.strip("`*").rstrip(",:;")
    return first if is_path(first) else ""


def _is_path_list(rows: list[str]) -> bool:
    if not rows:
        return False
    hits = sum(bool(_lead_path(r)) for r in rows)
    return hits >= max(1, round(len(rows) * 0.8))


# ------------------------------------------------------------------ rewrite per class


def rewrite(block: Block) -> str:
    """Rules output for one block. Never empty, and a rule that fails is not silence."""
    try:
        out = _RULES[block.kind](block)
    except Exception:  # noqa: BLE001 - a bug in one rule must not drop the block
        out = sentence(strip_unspoken(block.text))
    out = out or "a passage with nothing to read aloud."
    if block.kind not in ("prose", "bullets", "heading"):
        out = out[:1].upper() + out[1:]                  # a description starts a sentence
    return out


def _prose(b: Block) -> str:
    return sentence(inline(b.text))


def _heading(b: Block) -> str:
    return sentence(inline(b.text))


NUMBERED = re.compile(r"^\s*(\d+)[.)]\s+")


def _bullets(b: Block) -> str:
    """A bullet is its sentence; a numbered item keeps its number: "1, the answer"."""
    marks = [NUMBERED.match(l) for l in b.text.split("\n") if BULLET.match(l)]
    parts = [sentence((f"{m.group(1)}, " if m else "") + inline(item))
             for m, item in zip(marks, _items(b.text))]
    return " ".join(p for p in parts if p)


def _table(b: Block) -> str:
    rows = [r for r in b.text.split("\n") if r.strip()]
    body = [r for r in rows[1:] if not TABLE_SEP.match(r)]
    head = ["number" if c == "#" else inline(c) for c in _cells(rows[0])] if rows else []
    named = [h for h in head if h]
    cols = counted(len(head), "column")
    rows_n = counted(len(body), "row")
    if named:
        out = [f"a table with {cols}: {'; '.join(named)}; and {rows_n}."]
    else:
        out = [f"a table with {cols} and {rows_n}."]
    for n, row in enumerate(body, 1):
        out.append(_table_row(head, [inline(c) for c in _cells(row)], n))
    return " ".join(out)


VERB_HEADERS = {"does", "runs", "has", "means", "needs", "takes", "uses", "reads",
                "writes", "decides", "returns", "goes", "says"}


def _said(header: str, cell: str) -> str:
    """'Concerns are …', 'Status is …': the header's own number decides.

    A header that is itself a verb ("Runs", "Does") takes a colon instead.
    """
    if header.lower() in VERB_HEADERS:
        return f"{header}: {cell}"
    plural = re.search(r"[^su]s$", header) is not None
    return f"{header} {'are' if plural else 'is'} {cell}"


def _table_row(head: list[str], cells: list[str], n: int) -> str:
    """For Track M, Concerns are …; Status is …; Detail is …"""
    cells = [c.rstrip(".") for c in cells]                 # the row's own punctuation joins them
    pairs = [(h, c) for h, c in zip(head + [""] * len(cells), cells)]
    if not any(c for _, c in pairs):
        return f"Row {words(n)} is empty."
    (h0, c0), rest = pairs[0], [(h, c) for h, c in pairs[1:] if c]
    lead = f"For {h0} {c0}" if h0 and c0 else f"Row {words(n)}" + (f", {c0}" if c0 else "")
    said = [_said(h, c) if h else c for h, c in rest]
    return sentence(lead + (", " + "; ".join(said) if said else ""))


def _cells(row: str) -> list[str]:
    row = row.strip()
    if row.startswith("|"):
        row = row[1:]
    if row.endswith("|"):
        row = row[:-1]
    return [c.strip() for c in re.split(r"(?<!\\)\|", row)]


def _code(b: Block) -> str:
    n = len([l for l in b.text.split("\n") if l.strip()])
    lang = LANGUAGES.get(b.lang, b.lang)
    return f"a code block, {counted(n, 'line')}" + (f", {lang}." if lang else ".")


def _diff(b: Block) -> str:
    rows = b.text.split("\n")
    files: list[str] = []
    for r in rows:
        m = (re.match(r"^\+\+\+ (?:[a-z]/)?(\S+)", r)      # b/, or w/ with mnemonic prefixes
             or re.match(r"^diff --git \S+ (?:[a-z]/)?(\S+)", r))
        if m and m.group(1) != "/dev/null":
            name = path_name(m.group(1))
            if name not in files:
                files.append(name)
    added = sum(1 for r in rows if r.startswith("+") and not r.startswith("+++"))
    removed = sum(1 for r in rows if r.startswith("-") and not r.startswith("---"))
    if not files:
        what = "a diff"
    elif len(files) <= 3:
        what = f"a diff of {listed(files)}"
    else:
        what = f"a diff of {counted(len(files), 'file')}"
    return f"{what}, {counted(added, 'line')} added and {words(removed)} removed."


def _paths(b: Block) -> str:
    rows = _items(b.text) if BULLET.match(b.text.lstrip("\n").split("\n")[0]) else \
        [r for r in b.text.split("\n") if r.strip()]
    spoken = [say_path(p) for p in (_lead_path(r) for r in rows) if p]
    if len(spoken) == 1:
        return sentence("a path: " + spoken[0])
    if len(spoken) <= 5:
        return sentence(f"a list of {counted(len(spoken), 'path')}: " + "; ".join(spoken))
    return (f"a list of {counted(len(spoken), 'path')}. The first three: "
            + "; ".join(spoken[:3]) + f"; and {words(len(spoken) - 3)} more.")


def _diagram(b: Block) -> str:
    rows = [l for l in b.text.split("\n") if l.strip()]
    n = counted(len(rows), "line")
    if b.lang != "mermaid":
        return f"a text diagram, {n}."
    kind = "a diagram"
    for r in rows:
        r = r.strip()
        if r.startswith("%%"):
            continue
        for key, name in DIAGRAMS:
            if r.startswith(key):
                kind = name
                break
        break
    groups = sum(1 for r in rows if r.strip().startswith("subgraph"))
    inner = f" in {counted(groups, 'group')}" if groups else ""
    return f"a diagram: {kind}{inner}, {n}."


def _url(b: Block) -> str:
    m = URL.fullmatch(b.text.strip())
    return sentence(say_url(m.group(1))) if m else "a link."


def _token(b: Block) -> str:
    return "a long identifier."


def _frontmatter(b: Block) -> str:
    keys = [l for l in b.text.split("\n") if re.match(r"^[\w-]+:", l)]
    return f"a metadata header, {counted(len(keys), 'field')}."


_RULES = {
    "prose": _prose, "heading": _heading, "bullets": _bullets, "table": _table,
    "code": _code, "diff": _diff, "paths": _paths, "diagram": _diagram,
    "url": _url, "token": _token, "frontmatter": _frontmatter,
}


def spoken(text: str) -> str:
    """The whole text in spoken form, one block per line."""
    return "\n".join(rewrite(b) for b in classify(text))


HEADING_PAUSE_MS = 500    # before and after a heading
BLOCK_PAUSE_MS = 250      # between two other blocks


def segments(text: str) -> list[tuple[str, int]]:
    """The spoken blocks, each with the silence that follows it, in ms.

    A voice reads a heading into the next sentence unless a pause separates
    them, and punctuation cannot make one: `say` sends one sentence per request,
    so the silence is the player's to insert (N4).
    """
    out: list[tuple[str, int]] = []
    for block in classify(text):
        heading = block.kind == "heading"
        if heading and out:
            out[-1] = (out[-1][0], max(out[-1][1], HEADING_PAUSE_MS))
        out.append((rewrite(block), HEADING_PAUSE_MS if heading else BLOCK_PAUSE_MS))
    return out


def digits(text: str) -> list[str]:
    """The numbers in `text` by value, sorted: the invariant's currency.

    By value, so a date's "09" said as "9th" is the same number. A number in
    the output that the input lacks is the failure this guards against.
    """
    return sorted(str(int(d)) for d in re.findall(r"\d+", text))
