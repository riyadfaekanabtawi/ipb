#!/usr/bin/env python3
"""Builds the Trama website (Python 3 stdlib only).

Sources (edit these):
  web/src/page.html        page template (mini-mustache, see `render`)
  web/src/site.json        shared config: URLs, prices, phone rules, languages
  web/src/i18n/<lang>.json one dictionary per language (es, en, pt)
  web/src/legal.html       legal page template; web/src/legal/<lang>.json privacy notice + terms of use

Output (committed, and the only folder that is deployed):
  web/public/index.html, en/index.html, pt/index.html, sitemap.xml, llms.txt, llms-full.txt
  web/public/{privacidad,terminos}.html, en/{privacy,terms}.html, pt/{privacidade,termos}.html

Static files that are not generated (styles.css, app.js, assets/, robots.txt, site.webmanifest,
README.md) live directly in web/public/.

Usage:  python3 web/build.py          build and run the checks
        python3 web/build.py --check  fail if the committed output is stale (used by CI)
"""
from __future__ import annotations

import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "src"
PUBLIC = ROOT / "public"
LEAD_JS = ROOT.parent / "contact-api" / "lib" / "lead.js"

# --------------------------------------------------------------------------------------------
# Template engine: {{key}} (raw), {{key|e}} (HTML-escaped), {{.}} (current item),
# {{#key}}...{{/key}} (repeat for lists, render once if truthy), {{^key}}...{{/key}} (if falsy).
# Keys are dotted paths looked up from the innermost context outwards.
# --------------------------------------------------------------------------------------------
TOKEN = re.compile(r"\{\{\s*([#^/]?)\s*([\w.]+|\.)\s*(?:\|(\w+))?\s*\}\}")
MISSING = object()


def _get(obj, path):
    if path == ".":
        return obj
    for part in path.split("."):
        if isinstance(obj, dict) and part in obj:
            obj = obj[part]
        else:
            return MISSING
    return obj


def _lookup(stack, path):
    for ctx in reversed(stack):
        value = _get(ctx, path)
        if value is not MISSING:
            return value
    raise KeyError(f"template key not found: {path}")


def _parse(template):
    """Returns a tree of ('text', s) / ('var', key, filter) / ('section', kind, key, children)."""
    root, stack, pos = [], [], 0
    current = root
    for m in TOKEN.finditer(template):
        if m.start() > pos:
            current.append(("text", template[pos:m.start()]))
        kind, key, flt = m.groups()
        if kind in "#^" and kind:
            node = ("section", kind, key, [])
            current.append(node)
            stack.append((key, current))
            current = node[3]
        elif kind == "/":
            open_key, parent = stack.pop()
            if open_key != key:
                raise ValueError(f"mismatched section: opened {open_key}, closed {key}")
            current = parent
        else:
            current.append(("var", key, flt))
        pos = m.end()
    if stack:
        raise ValueError(f"unclosed section: {stack[-1][0]}")
    current.append(("text", template[pos:]))
    return root


def _render(nodes, stack):
    out = []
    for node in nodes:
        if node[0] == "text":
            out.append(node[1])
        elif node[0] == "var":
            value = _lookup(stack, node[1])
            text = "" if value is None else str(value)
            if node[2] == "e":
                text = html.escape(re.sub(r"<[^>]+>", "", text), quote=True)
            elif node[2]:
                raise ValueError(f"unknown filter {node[2]}")
            out.append(text)
        else:
            _, kind, key, children = node
            value = _lookup(stack, key)
            if kind == "^":
                if not value:
                    out.append(_render(children, stack))
            elif isinstance(value, list):
                for item in value:
                    out.append(_render(children, stack + [item]))
            elif value:
                out.append(_render(children, stack + [value] if isinstance(value, dict) else stack))
    return "".join(out)


def render(template, context):
    # A section tag alone on its line leaves no blank line behind.
    template = re.sub(r"(?m)^[ \t]*(\{\{[#^/][^}]*\}\})[ \t]*\n", r"\1", template)
    return _render(_parse(template), [context])


# --------------------------------------------------------------------------------------------
# Page context
# --------------------------------------------------------------------------------------------
def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def script_json(data):
    """JSON safe to inline inside <script>."""
    return json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")


def strip_tags(text):
    return re.sub(r"<[^>]+>", "", text)


def annual_monthly(price):
    """Monthly equivalent of the annual price (2 months free), rounded half up."""
    return int(price * 10 / 12 + 0.5)


def money(amount, d, markup=False):
    grouped = f"{amount:,}".replace(",", d["pricing"]["thousands"])
    currency = d["pricing"]["currency"]
    if markup:
        return f'<span class="price__cur">{currency.strip()}</span>{grouped}'
    return f"{currency}{grouped}"


def page_url(site, lang):
    return f"{site['base_url']}/{lang['dir']}index.html"


def build_context(site, langs, dicts, code, legal):
    d = dicts[code]
    lang = next(l for l in langs if l["code"] == code)
    base = "../" if lang["dir"] else ""
    url = page_url(site, lang)

    alternates = [{"hreflang": h, "href": page_url(site, l)} for l in langs for h in l["hreflang"]]
    default = next(l for l in langs if l.get("default"))
    alternates.append({"hreflang": "x-default", "href": page_url(site, default)})

    def rel_href(target):
        return f"{base}{target['dir']}index.html" if target["code"] != code else "index.html"

    # The web app picks its language from ?lang= (then the saved choice, then the browser). The
    # EN/PT landings pass theirs; the Spanish one is the x-default, so it leaves the choice open.
    login_url = site["login_url"] if lang.get("default") else f"{site['login_url']}?lang={code}"

    lang_links = [{
        "code": l["code"], "label": l["label"], "flag": l["flag"], "name": l["name"], "hreflang": l["hreflang"][0],
        "href": rel_href(l), "current": l["code"] == code,
    } for l in langs]

    plans = []
    for p in site["plans"]:
        text = d["pricing"]["plans"][p["id"]]
        plans.append({
            "id": p["id"], "value": p["value"], "featured": bool(p.get("featured")), "from": bool(p.get("from")),
            "badge": text.get("badge", ""), "name": text["name"], "for": text["for"], "features": text["features"],
            "caveat": text.get("caveat", ""), "cta": text["cta"],
            "monthly": p["monthly"], "annual_monthly": annual_monthly(p["monthly"]), "annual_total": p["monthly"] * 10,
            "price_monthly": money(p["monthly"], d, True), "price_annual": money(annual_monthly(p["monthly"]), d, True),
            "billed_annual": d["pricing"]["billed_annual"].replace("{total}", money(p["monthly"] * 10, d)),
        })

    icons = {"yes": "yes", "no": "no", "part": "part", "": ""}

    def cell(side, pair):
        state, text = pair
        return {"side": side, "state": state or "info", "icon": icons[state], "sr": d["compare"]["sr"].get(state, ""), "text": text}

    rows = [{"label": r["label"], "cells": [cell("app", r["app"]), cell("web", r["web"])]} for r in d["compare"]["rows"]]
    cards = []
    for side, device in (("app", "tablet"), ("web", "monitor")):
        cards.append({
            "side": side, "device": device, "name": d["compare"][side]["name"], "sub": d["compare"][side]["sub"],
            "items": [{**cell(side, r[side]), "label": r["label"]} for r in d["compare"]["rows"]],
        })

    default_country = site["default_country"][code]
    countries = [{**c, "name": d["countries"][c["iso"]], "selected": c["iso"] == default_country} for c in site["countries"]]

    tabs = [{**t, "selected": "true" if i == 0 else "false", "first": i == 0} for i, t in enumerate(d["showcase"]["tabs"])]

    suggest = {l["code"]: {**dicts[l["code"]]["suggest"], "href": rel_href(l)} for l in langs if l["code"] != code}
    i18n_js = {
        "lang": code,
        "tabs": {t["key"]: t["alt"] for t in d["showcase"]["tabs"]},
        "defaultAlt": d["showcase"]["default_alt"],
        "phone": {c["iso"]: {"dial": c["dial"], "lengths": c["lengths"], "name": d["countries"][c["iso"]]} for c in site["countries"]},
        "t": d["js"],
        "suggest": suggest,
    }

    ctx = dict(d)
    ctx.update({
        "site": site, "lang": lang, "base": base, "page_url": url, "alternates": alternates, "login_url": login_url,
        "og_alternates": [dicts[l["code"]]["meta"]["og_locale"] for l in langs if l["code"] != code],
        "langs": lang_links, "plans": plans, "countries": countries,
        "compare_rows": rows, "compare_cards": cards, "showcase_tabs": tabs,
        "showcase_first_alt": tabs[0]["alt"],
        "licensing_steps": [{**s, "n": i + 1} for i, s in enumerate(d["licensing"]["steps"])],
        "cap_plant_0": d["product"]["cap"]["plants"][0], "cap_plant_1": d["product"]["cap"]["plants"][1],
        "cap_plant_2": d["product"]["cap"]["plants"][2],
        "year": site["lastmod"][:4],
        "i18n_js": script_json(i18n_js),
        "legal": {
            "privacy": legal[code]["ui"]["privacy"], "terms": legal[code]["ui"]["terms"],
            "privacy_href": lang["legal"]["privacy"], "terms_href": lang["legal"]["terms"],
            "form_notice": legal[code]["ui"]["form_notice"].replace("{privacy_href}", lang["legal"]["privacy"]),
        },
    })
    ctx["jsonld_graph"] = script_json(jsonld_graph(site, d, url, plans))
    ctx["jsonld_faq"] = script_json(jsonld_faq(d, url))
    return ctx


# --------------------------------------------------------------------------------------------
# Legal pages (privacy notice, terms of use)
# --------------------------------------------------------------------------------------------
LEGAL_DOCS = ("privacy", "terms")


def legal_url(site, lang, doc):
    return f"{site['base_url']}/{lang['dir']}{lang['legal'][doc]}"


def fill(text, values):
    for key, value in values.items():
        text = text.replace("{" + key + "}", value)
    return text


def legal_context(site, langs, legal, code, doc):
    lang = next(l for l in langs if l["code"] == code)
    L = legal[code]
    base = "../" if lang["dir"] else ""
    cfg = site["legal"]
    address = cfg.get("address", "").strip()
    values = {
        "owner": cfg["owner"],
        "address_sentence": fill(L["ui"]["address_sentence"], {"address": address}) if address else "",
        "jurisdiction": cfg["jurisdiction"][code],
        "contact_href": "index.html#contacto",
        "privacy_href": lang["legal"]["privacy"],
    }
    sections = []
    for sec in L[doc]["sections"]:
        body = []
        for block in sec["body"]:
            body.append({
                "p": fill(block.get("p", ""), values).strip(),
                "list": {"items": [fill(i, values) for i in block["ul"]]} if "ul" in block else None,
            })
        sections.append({"id": sec["id"], "h": sec["h"], "body": body})
    content = {**L[doc], "lead": fill(L[doc]["lead"], values), "sections": sections}

    url = legal_url(site, lang, doc)
    alternates = [{"hreflang": h, "href": legal_url(site, l, doc)} for l in langs for h in l["hreflang"]]
    default = next(l for l in langs if l.get("default"))
    alternates.append({"hreflang": "x-default", "href": legal_url(site, default, doc)})
    lang_links = [{
        "label": l["label"], "flag": l["flag"], "name": l["name"], "hreflang": l["hreflang"][0],
        "href": (f"{base}{l['dir']}" if l["code"] != code else "") + l["legal"][doc], "current": l["code"] == code,
    } for l in langs]
    other = "terms" if doc == "privacy" else "privacy"
    jsonld = {
        "@context": "https://schema.org", "@type": "WebPage", "name": content["title"], "url": url,
        "description": content["description"], "inLanguage": lang["hreflang"][0], "dateModified": cfg["updated"],
        "isPartOf": {"@type": "WebSite", "name": "Trama", "url": page_url(site, default)},
        "publisher": {"@type": "Organization", "name": "Trama", "url": site["base_url"]},
    }
    return {
        "site": site, "lang": lang, "base": base, "meta_lang": lang["hreflang"][0], "doc": content, "doc_url": url,
        "alternates": alternates, "langs": lang_links, "lang_aria": L["ui"]["privacy"], "ui": L["ui"],
        "other": {"href": lang["legal"][other], "label": L["ui"][other]},
        "privacy_href": lang["legal"]["privacy"], "terms_href": lang["legal"]["terms"], "is_privacy": doc == "privacy",
        "year": site["lastmod"][:4], "jsonld": script_json(jsonld),
    }


def check_legal(name, page):
    errors = []
    if re.search(r"\{\{\s*[#^/]?\s*[\w.]+", page):
        errors.append(f"{name}: unrendered template tag")
    if re.search(r"\{(owner|address|address_sentence|jurisdiction|contact_href|privacy_href)\}", page):
        errors.append(f"{name}: unfilled placeholder")
    if "riyad.faek" in page:
        errors.append(f"{name}: the contact email must not appear on the page")
    try:
        json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>', page, re.S).group(1))
    except Exception as e:  # noqa: BLE001
        errors.append(f"{name}: JSON-LD does not parse: {e}")
    return errors


def jsonld_graph(site, d, url, plans):
    b = site["base_url"]
    lang = d["meta"]["lang"]
    offers = []
    for p in plans:
        spec = {"@type": "UnitPriceSpecification", "priceCurrency": "USD", "unitCode": "MON",
                "billingDuration": "P1M", "valueAddedTaxIncluded": False}
        if p["from"]:
            spec["minPrice"] = p["monthly"]
        else:
            spec["price"] = p["monthly"]
        offers.append({
            "@type": "Offer", "name": p["name"], "description": "; ".join(strip_tags(f) for f in p["features"]),
            "price": p["monthly"], "priceCurrency": "USD", "priceSpecification": spec,
            "url": f"{url}#plan-{p['id']}", "availability": "https://schema.org/InStock",
            "seller": {"@id": f"{b}/#org"},
        })
    return {
        "@context": "https://schema.org",
        "@graph": [
            {"@type": "Organization", "@id": f"{b}/#org", "name": "Trama", "url": f"{b}/index.html",
             "logo": f"{b}/assets/icon-512.png",
             "contactPoint": {"@type": "ContactPoint", "contactType": "sales", "url": f"{url}#contacto",
                              "availableLanguage": ["es", "en", "pt"], "areaServed": ["MX", "US", "BR", "419"]}},
            {"@type": "WebSite", "@id": f"{url}#website", "url": url, "name": "Trama", "inLanguage": lang,
             "description": d["meta"]["description"], "publisher": {"@id": f"{b}/#org"}},
            {"@type": "SoftwareApplication", "@id": f"{url}#app", "name": "Trama", "alternateName": d["meta"]["app_alt_name"],
             "applicationCategory": "BusinessApplication", "applicationSubCategory": d["meta"]["app_category"],
             "operatingSystem": "iPadOS 17+, Android 8.0+, Web", "inLanguage": lang, "url": url,
             "image": f"{b}/assets/og.jpg",
             "screenshot": [f"{b}/assets/shots/{s}.webp" for s in ("dash", "board", "detail", "cal")],
             "description": d["meta"]["app_description"], "featureList": d["meta"]["feature_list"],
             "offers": offers, "publisher": {"@id": f"{b}/#org"}},
        ],
    }


def jsonld_faq(d, url):
    return {
        "@context": "https://schema.org", "@type": "FAQPage", "@id": f"{url}#preguntas", "inLanguage": d["meta"]["lang"],
        "mainEntity": [{"@type": "Question", "name": strip_tags(i["q"]),
                        "acceptedAnswer": {"@type": "Answer", "text": strip_tags(i["a"])}} for i in d["faq"]["items"]],
    }


# --------------------------------------------------------------------------------------------
# sitemap.xml and llms*.txt
# --------------------------------------------------------------------------------------------
def sitemap(site, langs, dicts):
    links = "".join(
        f'\n    <xhtml:link rel="alternate" hreflang="{h}" href="{page_url(site, l)}"/>' for l in langs for h in l["hreflang"])
    default = next(l for l in langs if l.get("default"))
    links += f'\n    <xhtml:link rel="alternate" hreflang="x-default" href="{page_url(site, default)}"/>'
    b = site["base_url"]
    urls = []
    for l in langs:
        m = dicts[l["code"]]["meta"]
        board_alt = html.escape(dicts[l["code"]]["product"]["board"]["alt"])
        urls.append(f"""  <url>
    <loc>{page_url(site, l)}</loc>
    <lastmod>{site['lastmod']}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>{'1.0' if l.get('default') else '0.9'}</priority>{links}
    <image:image><image:loc>{b}/assets/og.jpg</image:loc><image:title>{html.escape(m['og_title'])}</image:title></image:image>
    <image:image><image:loc>{b}/assets/shots/board.webp</image:loc><image:title>{board_alt}</image:title></image:image>
  </url>""")
    for doc in LEGAL_DOCS:
        doc_links = "".join(
            f'\n    <xhtml:link rel="alternate" hreflang="{h}" href="{legal_url(site, l, doc)}"/>' for l in langs for h in l["hreflang"])
        doc_links += f'\n    <xhtml:link rel="alternate" hreflang="x-default" href="{legal_url(site, default, doc)}"/>'
        for l in langs:
            urls.append(f"""  <url>
    <loc>{legal_url(site, l, doc)}</loc>
    <lastmod>{site['legal']['updated']}</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>{doc_links}
  </url>""")
    urls.append(f"  <url><loc>{b}/llms.txt</loc><lastmod>{site['lastmod']}</lastmod><priority>0.3</priority></url>")
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml" '
            'xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">\n' + "\n".join(urls) + "\n</urlset>\n")


def llms(site, langs, dicts, full):
    d = dicts["es"]
    L = d["llms"]
    url = page_url(site, langs[0])
    out = ["# Trama", "", f"> {L['summary']}", "", L["origin"], "", f"## {L['h_does']}"]
    out += [f"- {x}" for x in L["does"]]
    out += ["", f"## {L['h_pricing']}"]
    for p in site["plans"]:
        t = d["pricing"]["plans"][p["id"]]
        prefix = f"{d['pricing']['from']} " if p.get("from") else ""
        feats = "; ".join(strip_tags(f) for f in t["features"] + ([t["caveat"]] if t.get("caveat") else []))
        out.append(f"- {t['name']}: {prefix}${p['monthly']} USD/mes (anual: ${annual_monthly(p['monthly'])} USD/mes, "
                   f"${p['monthly'] * 10:,} USD/año). {feats}.")
    out += [f"- {L['annual_note']}", "", f"## {L['h_buy']}"]
    out += [f"{i + 1}. {s['h']}: {strip_tags(s['p'])}" for i, s in enumerate(d["licensing"]["steps"])]
    out += ["", f"## {L['h_contact']}", f"- {L['contact'].replace('{url}', url)}", "", f"## {L['h_langs']}"]
    out += [f"- [{l['name']}]({page_url(site, l)})" for l in langs]
    if full:
        c = d["compare"]
        out += ["", f"## {L['h_compare']}", f"{strip_tags(c['h2'])} {strip_tags(c['lead'])}", ""]
        out += [f"- {r['label']}: app: {r['app'][1]}; web: {r['web'][1]}." for r in c["rows"]]
        out += ["", f"## {L['h_faq']}"]
        for i in d["faq"]["items"]:
            out += ["", f"### {strip_tags(i['q'])}", strip_tags(i["a"])]
    out += ["", f"## {L['h_links']}", f"- [Trama]({url}): {L['link_site']}",
            f"- [{L['link_full']}]({site['base_url']}/llms-full.txt)", ""]
    return "\n".join(out)


# --------------------------------------------------------------------------------------------
# Checks
# --------------------------------------------------------------------------------------------
def check_page(code, page, d):
    errors = []
    blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>', page, re.S)
    if len(blocks) != 2:
        errors.append(f"{code}: expected 2 JSON-LD blocks, found {len(blocks)}")
    parsed = []
    for block in blocks:
        try:
            parsed.append(json.loads(block))
        except json.JSONDecodeError as e:
            errors.append(f"{code}: JSON-LD does not parse: {e}")
    faq = next((p for p in parsed if p.get("@type") == "FAQPage"), None)
    visible = [strip_tags(html.unescape(q)) for q in re.findall(r"<summary>(.*?)</summary>", page)]
    if not faq or [q["name"] for q in faq["mainEntity"]] != visible:
        errors.append(f"{code}: FAQPage JSON-LD does not match the visible FAQ")
    graph = next((p for p in parsed if "@graph" in p), {"@graph": []})
    app = next((n for n in graph["@graph"] if n.get("@type") == "SoftwareApplication"), {})
    if len(app.get("offers", [])) != 4:
        errors.append(f"{code}: SoftwareApplication must list 4 offers")
    if re.search(r"\{\{\s*[#^/]?\s*[\w.]+", page):
        errors.append(f"{code}: unrendered template tag")
    if "riyad.faek" in page:
        errors.append(f"{code}: the contact email must not appear on the page")
    if f'hreflang="x-default"' not in page or "<link rel=\"canonical\"" not in page:
        errors.append(f"{code}: missing canonical or x-default")
    if not re.search(r'window\.TRAMA_I18N = \{.*\};', page):
        errors.append(f"{code}: missing TRAMA_I18N")
    try:
        json.loads(re.search(r"window\.TRAMA_I18N = (\{.*?\});</script>", page).group(1).replace("<\\/", "</"))
    except Exception as e:  # noqa: BLE001
        errors.append(f"{code}: TRAMA_I18N is not valid JSON: {e}")
    return errors


def check_phone_rules(site):
    """contact-api/lib/lead.js keeps its own copy of the phone table; they must agree."""
    if not LEAD_JS.exists():
        return []
    source = LEAD_JS.read_text(encoding="utf-8")
    api = {iso: (dial, [int(n) for n in lengths.split(",")])
           for iso, dial, lengths in re.findall(r'(\w\w):\s*\{\s*dial:\s*"(\d+)",\s*lengths:\s*\[([\d,\s]+)\]', source)}
    web = {c["iso"]: (c["dial"], c["lengths"]) for c in site["countries"]}
    diff = sorted(iso for iso in set(api) | set(web) if api.get(iso) != web.get(iso))
    if diff:
        return [f"phone rules differ between web/src/site.json and contact-api/lib/lead.js for: {', '.join(diff)}"]
    return []


def check_dicts(dicts):
    """Every language must have the same keys (and list lengths) as Spanish."""
    errors = []

    def shape(obj):
        if isinstance(obj, dict):
            return {k: shape(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [shape(v) for v in obj] if obj and isinstance(obj[0], (dict, list)) else len(obj) and "list"
        return "v"

    ref = shape({k: v for k, v in dicts["es"].items() if k != "llms"})  # llms*.txt are Spanish only
    for code, d in dicts.items():
        if code != "es" and shape(d) != ref:
            errors.append(f"i18n/{code}.json does not have the same keys/lists as es.json")
    return errors


def main():
    site = load_json(SRC / "site.json")
    langs = site["languages"]
    dicts = {l["code"]: load_json(SRC / "i18n" / f"{l['code']}.json") for l in langs}
    template = (SRC / "page.html").read_text(encoding="utf-8")
    legal = {l["code"]: load_json(SRC / "legal" / f"{l['code']}.json") for l in langs}
    legal_template = (SRC / "legal.html").read_text(encoding="utf-8")

    outputs, errors = {}, check_dicts(dicts) + check_phone_rules(site)
    for l in langs:
        page = render(template, build_context(site, langs, dicts, l["code"], legal))
        errors += check_page(l["code"], page, dicts[l["code"]])
        outputs[f"{l['dir']}index.html"] = page
        for doc in LEGAL_DOCS:
            name = f"{l['dir']}{l['legal'][doc]}"
            outputs[name] = render(legal_template, legal_context(site, langs, legal, l["code"], doc))
            errors += check_legal(name, outputs[name])
    outputs["sitemap.xml"] = sitemap(site, langs, dicts)
    outputs["llms.txt"] = llms(site, langs, dicts, full=False)
    outputs["llms-full.txt"] = llms(site, langs, dicts, full=True)
    for name in ("llms.txt", "llms-full.txt"):
        if "riyad.faek" in outputs[name]:
            errors.append(f"{name}: the contact email must not appear")

    if errors:
        print("\n".join(f"error: {e}" for e in errors), file=sys.stderr)
        return 1

    if "--check" in sys.argv:
        stale = [n for n, text in outputs.items()
                 if not (PUBLIC / n).exists() or (PUBLIC / n).read_text(encoding="utf-8") != text]
        if stale:
            print("Generated files are stale, run `python3 web/build.py` and commit:\n  " + "\n  ".join(stale), file=sys.stderr)
            return 1
        print("web/public is up to date")
        return 0

    for name, text in outputs.items():
        path = PUBLIC / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        print(f"wrote web/public/{name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
