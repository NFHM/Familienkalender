"""Baut index.html aus src/template.html und dem Basis-CSS. Aufruf: python3 build.py [URL] [KEY]"""
import sys, pathlib
root = pathlib.Path(__file__).parent
tpl = (root / "src/template.html").read_text()
css = (root / "src/base.css").read_text()
url = sys.argv[1] if len(sys.argv) > 1 else "HIER_SUPABASE_URL_EINTRAGEN"
key = sys.argv[2] if len(sys.argv) > 2 else "HIER_PUBLISHABLE_KEY_EINTRAGEN"
out = tpl.replace("/*BASECSS*/", css).replace("/*URL*/", url).replace("/*KEY*/", key)
(root / "index.html").write_text(out)
print("index.html", len(out), "Bytes")
