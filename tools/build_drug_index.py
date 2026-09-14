"""Build the bundled drug-name index from openFDA's NDC dataset.

Downloads the full NDC product list, keeps human prescription drugs and OTC
drugs taken by mouth/eye/nose/etc. (dropping topical soaps and sunscreens,
homeopathics, and bulk ingredients), and writes a compact list of
brand/generic name pairs to Rxcall/Rxcall/Resources/drug-index.json.

The index is used entirely on-device: for autocomplete when typing a
medication name, and for picking the drug name out of OCR'd label text.
Only a confirmed drug name is ever sent to the recall API.

Run from the repo root:  python3 tools/build_drug_index.py
"""
import io, json, re, sys, urllib.request, zipfile
from pathlib import Path

URL = "https://download.open.fda.gov/drug/ndc/drug-ndc-0001-of-0001.json.zip"
OUT = Path(__file__).resolve().parent.parent / "Rxcall/Rxcall/Resources/drug-index.json"

OTC_ROUTES = {"ORAL", "OPHTHALMIC", "NASAL", "RECTAL", "VAGINAL", "SUBLINGUAL", "BUCCAL",
              "TRANSDERMAL", "RESPIRATORY (INHALATION)", "AURICULAR (OTIC)", "OTIC"}
DROP_CATEGORIES = {"UNAPPROVED HOMEOPATHIC", "BULK INGREDIENT", "DRUG FOR FURTHER PROCESSING"}

def keep(r):
    if not r.get("finished") or r.get("marketing_category") in DROP_CATEGORIES:
        return False
    t = r.get("product_type", "")
    if t == "HUMAN PRESCRIPTION DRUG":
        return True
    if t == "HUMAN OTC DRUG":
        return bool(set(r.get("route", [])) & OTC_ROUTES)
    return False

def tidy(s):
    return re.sub(r"\s+", " ", s or "").strip()

# Words that describe the form or strength rather than the drug; the generic
# is cut at the first one. "metformin hydrochloride extended-release tablets
# 500 mg" -> "metformin hydrochloride".
FORM_WORDS = r"""\b(\d+(\.\d+)?\s*(mg|mcg|g|ml|%|meq|units?|iu)|tablets?|tabs?|capsules?|caps?|
    injection|injectable|solution|suspension|syrup|elixir|oral|topical|ophthalmic|nasal|
    extended|delayed|immediate|controlled|sustained|release|er|xr|xl|sr|cr|dr|odt|
    chewable|coated|film|usp|kit|spray|drops?|cream|ointment|gel|patch|inhaler|powder|
    lozenges?|liquid|concentrate|for|in|with|plus)\b.*$"""
FORM_RE = re.compile(FORM_WORDS, re.I | re.X)
# Salt suffixes that vary between products but not in how people (or recall
# notices) refer to the drug. Only stripped from multi-word ingredients.
SALTS = {"hydrochloride", "hcl", "sodium", "potassium", "calcium", "sulfate", "acetate",
         "maleate", "citrate", "tartrate", "mesylate", "succinate", "besylate", "phosphate",
         "bromide", "hydrobromide", "fumarate", "monohydrate", "anhydrous", "dihydrate",
         "magnesium", "bitartrate", "nitrate", "propionate", "valerate", "decanoate"}

# Retailers listed as the "brand" of store-label products. As a bare brand name
# they identify a shop, not a drug — and they appear on every pharmacy label.
RETAILERS = {"walgreens", "cvs", "cvs pharmacy", "rite aid", "kroger", "walmart", "equate",
             "target", "up & up", "up and up", "kirkland", "kirkland signature", "costco",
             "publix", "meijer", "h-e-b", "heb", "safeway", "amazon", "amazon basic care",
             "good sense", "goodsense", "dollar general", "family dollar", "rexall",
             "wegmans", "giant", "stop & shop", "albertsons", "sam's club", "member's mark",
             "walgreen", "duane reade", "harris teeter", "topcare", "top care", "quality choice",
             "leader", "premier value", "sunmark", "health mart", "healthmart", "medline",
             "mckesson", "cardinal health", "major", "rugby", "geri-care", "gericare"}

def clean_generic(g):
    ingredients = re.split(r",|/|\band\b", g.lower())
    out = []
    for ing in ingredients:
        ing = FORM_RE.sub("", ing).strip(" ,-")
        words = ing.split()
        while len(words) > 1 and words[-1] in SALTS:
            words.pop()
        if words and " ".join(words) not in out:
            out.append(" ".join(words))
    return " and ".join(out)

def main():
    print("downloading", URL, file=sys.stderr)
    raw = urllib.request.urlopen(URL, timeout=300).read()
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        records = json.load(z.open(z.namelist()[0]))["results"]
    entries = {}
    for r in records:
        if not keep(r):
            continue
        if "KIT" in (r.get("dosage_form") or ""):
            continue
        brand, generic = tidy(r.get("brand_name")), clean_generic(tidy(r.get("generic_name")))
        if not generic:
            continue
        # A "brand" that's just the generic (with or without salt/form words),
        # as repackagers often list, isn't a brand.
        b = clean_generic(brand)
        if (not brand or b == generic or generic.startswith(b) or b.startswith(generic)
                or brand.lower() in RETAILERS):
            brand = ""
        key = brand.upper() if brand else "|" + generic
        # One row per brand; keep the shortest generic seen for it.
        if key not in entries or len(generic) < len(entries[key]["g"]):
            entries[key] = {"b": brand, "g": generic} if brand else {"g": generic}
    out = sorted(entries.values(), key=lambda e: (e.get("b") or e["g"]).lower())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, separators=(",", ":"), ensure_ascii=False) + "\n")
    print(f"{len(out)} entries -> {OUT} ({OUT.stat().st_size/1e6:.1f} MB)", file=sys.stderr)

if __name__ == "__main__":
    main()
