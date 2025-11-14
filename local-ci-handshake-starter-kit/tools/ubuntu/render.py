#!/usr/bin/env python3
# Minimal renderer: builds index.md and index.html from session-index.json and requests
import argparse, json, os, pathlib, html

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", required=True)
    ap.add_argument("--raw", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--requests", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    pathlib.Path(args.out).mkdir(parents=True, exist_ok=True)
    idx_path = os.path.join(args.raw, "session-index.json")

    manifest = json.load(open(args.manifest, encoding="utf-8"))
    requests = json.load(open(args.requests, encoding="utf-8"))
    index = json.load(open(idx_path, encoding="utf-8")) if os.path.exists(idx_path) else {"pairs":[]}

    lines = []
    lines.append("# VI Compare Report - run {}".format(args.run))
    lines.append("- LabVIEW target: {}".format(requests.get('labview',{}).get('target_version','(unspecified)')))
    lines.append("")
    lines.append("| Pair ID | Baseline | Candidate | HTML | JSON | Log |")
    lines.append("|---|---|---|---|---|---|")
    for p in index.get("pairs", []):
        lv = p.get("lvcompare", {})
        html_r = lv.get("html_report","")
        json_r = lv.get("json_report","")
        log_f = lv.get("log","")
        lines.append("| {} | `{}` | `{}` | [{}]({}) | [{}]({}) | [{}]({}) |".format(
            p.get('pair_id',''), p.get('baseline',''), p.get('candidate',''),
            os.path.basename(html_r), html_r, os.path.basename(json_r), json_r, os.path.basename(log_f), log_f))

    md = "\n".join(lines)
    with open(os.path.join(args.out, "index.md"), "w", encoding="utf-8") as f:
        f.write(md)

    html_doc = "<!doctype html><html><head><meta charset='utf-8'><title>VI Compare - {}</title>".format(html.escape(args.run))
    html_doc += "<style>body{{font-family:system-ui,Segoe UI,Roboto,Arial,sans-serif;margin:24px}}table{{border-collapse:collapse}}td,th{{border:1px solid #ddd;padding:6px}}</style></head><body>"
    html_doc += "<pre style='background:#f6f8fa;padding:8px'>Run: {}</pre>".format(html.escape(args.run))
    html_doc += "<article>{}</article>".format(md.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('\n','<br/>\n'))
    html_doc += "</body></html>"
    with open(os.path.join(args.out, "index.html"), "w", encoding="utf-8") as f:
        f.write(html_doc)

if __name__ == "__main__":
    main()
