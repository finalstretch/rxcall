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

# Topical OTC products are mostly soaps, sanitizers and sunscreens, which
# would drown the list. A topical is kept only if it contains a real
# medicinal ingredient someone would call "my cream / ointment / drops".
TOPICAL_DRUGS = {"hydrocortisone", "bacitracin", "neomycin", "polymyxin", "clotrimazole", "miconazole",
                 "terbinafine", "tolnaftate", "butenafine", "ketoconazole", "benzoyl peroxide",
                 "salicylic acid", "lidocaine", "benzocaine", "pramoxine", "diphenhydramine",
                 "calamine", "permethrin", "selenium sulfide", "coal tar", "pyrithione", "minoxidil",
                 "capsaicin", "methyl salicylate", "trolamine", "diclofenac", "adapalene", "tretinoin",
                 "urea", "ammonium lactate", "povidone", "mupirocin", "nystatin", "clindamycin",
                 "erythromycin", "metronidazole", "tacrolimus", "triamcinolone", "betamethasone",
                 "clobetasol", "fluocinonide", "mometasone", "desonide", "imiquimod", "ivermectin",
                 "silver sulfadiazine", "acyclovir", "docosanol", "phenol", "zinc oxide", "menthol",
                 "camphor", "dibucaine", "witch hazel", "hydroquinone", "azelaic", "dapsone",
                 "lindane", "spinosad", "malathion", "crotamiton", "sulfur", "resorcinol"}

def is_medicinal_topical(generic):
    g = generic.lower()
    return any(d in g for d in TOPICAL_DRUGS)

def keep(r):
    if not r.get("finished") or r.get("marketing_category") in DROP_CATEGORIES:
        return False
    t = r.get("product_type", "")
    if t == "HUMAN PRESCRIPTION DRUG":
        return True
    if t == "HUMAN OTC DRUG":
        if set(r.get("route", [])) & OTC_ROUTES:
            return True
        return is_medicinal_topical(r.get("generic_name") or "")
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
    lozenges?|liquid|concentrate|for|in|with|plus)(?![a-z0-9]).*$"""
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

# Words that describe what a product does or who it's for rather than naming it.
# A "brand" made only of these ("Pain Reliever", "Extra Strength Antacid") is a
# store-label description, not a name anyone would search for.
DESCRIPTIVE = {"pain", "reliever", "relief", "extra", "strength", "maximum", "regular", "antacid",
               "tablets", "tablet", "caplets", "gas", "cold", "flu", "allergy", "sinus", "sleep",
               "aid", "cough", "nighttime", "daytime", "night", "day", "time", "childrens",
               "children's", "children", "infants", "infant", "adult", "adults", "fever", "reducer",
               "headache", "migraine", "nasal", "spray", "eye", "drops", "drop", "ear", "stomach",
               "heartburn", "acid", "laxative", "stool", "softener", "fiber", "sleep", "multi",
               "symptom", "severe", "non", "drowsy", "chewable", "liquid", "gels", "gel", "capsules",
               "softgels", "junior", "and", "&", "plus", "with", "for", "the", "of", "formula",
               "original", "fast", "acting", "rapid", "release", "hour", "hr", "pm", "am", "mg",
               "coated", "enteric", "low", "dose", "dye", "free", "concentrated", "oral", "suspension",
               "mucus", "chest", "congestion", "decongestant", "antihistamine", "motion", "sickness",
               "nausea", "anti", "diarrheal", "itch", "allergies", "care", "health", "pharmacy",
               "brand", "value", "premium", "quality", "choice", "basic", "signature", "select",
               # packaging words on tubes, boxes and bottles that OCR reads before the name
               "cream", "creme", "ointment", "lotion", "balm", "white", "clear", "skin", "medicated",
               "treatment", "remover", "wart", "antifungal", "dandruff", "first", "ultra", "max",
               "relieving", "itch", "rash", "diaper", "muscle", "rub", "foot", "athlete's", "athletes",
               "jock", "ringworm", "hair", "scalp", "shampoo", "sun", "burn", "lip", "sore", "throat",
               "ear", "wax", "mouth", "tooth", "teeth", "sensitive", "whitening", "toothpaste", "rinse",
               "antiseptic", "antibiotic", "antibacterial", "ointments", "creams", "patch", "patches",
               "roll", "on", "stick", "wipes", "pads", "spray", "mist", "cough", "syrup", "tablets",
               "kids", "baby", "toddler", "menthol", "cooling", "warming", "penetrating", "therapy"}

def is_descriptive(brand, generic):
    words = re.findall(r"[a-z0-9&']+", brand.lower())
    generic_words = set(re.findall(r"[a-z0-9]+", generic))
    return all(w in DESCRIPTIVE or w in generic_words or w.isdigit() for w in words)

def strip_retailer(brand):
    low = brand.lower()
    for r in sorted(RETAILERS, key=len, reverse=True):
        if low.startswith(r + " "):
            return brand[len(r):].strip(" -:")
    return brand

LEADING_STRENGTH = re.compile(r"^\s*\d+(\.\d+)?\s*(mg|mcg|g|ml|%|meq|units?|iu)\s+", re.I)

# Sunscreens and the like aren't medications anyone tracks for recalls.
COSMETIC = re.compile(r"sunscreen|sunblock|\bspf|broad spectrum|titanium dioxide|avobenzone|octinoxate|"
                      r"octocrylene|homosalate|oxybenzone|octisalate|sanitizer|hand wash|handwash|hand soap", re.I)

def clean_generic(g):
    ingredients = re.split(r",|/|\band\b", g.lower())
    out = []
    for ing in ingredients:
        ing = LEADING_STRENGTH.sub("", ing)
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
        if COSMETIC.search((r.get("brand_name") or "") + " " + (r.get("generic_name") or "")):
            continue
        brand, generic = tidy(r.get("brand_name")), clean_generic(tidy(r.get("generic_name")))
        if not generic:
            continue
        brand = strip_retailer(brand)
        if is_descriptive(brand, generic):
            brand = ""
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
