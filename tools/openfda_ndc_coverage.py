"""Pull every Ongoing drug enforcement record and measure how often an NDC is
recoverable (structured openfda block, or written in the description text),
what lot-number strings look like, and how much of the set is hospital product.

Run with:  python3 tools/openfda_ndc_coverage.py
"""
import json, re, urllib.request, urllib.parse, collections
BASE = "https://api.fda.gov/drug/enforcement.json"
recs = []
for skip in (0, 1000, 2000):
    url = BASE + "?" + urllib.parse.urlencode({"search": "status:Ongoing", "limit": 1000, "skip": skip})
    with urllib.request.urlopen(url, timeout=60) as r:
        recs += json.load(r)["results"]
print("ongoing records fetched:", len(recs))

NDC = re.compile(r"\b\d{4,5}-\d{3,4}-\d{1,2}\b")
no_of = [r for r in recs if "openfda" not in r or not r["openfda"].get("generic_name")]
ndc_in_text = [r for r in no_of if NDC.search(r.get("product_description", ""))]
print(f"without openfda block: {len(no_of)}; of those, NDC found in description text: {len(ndc_in_text)} ({100*len(ndc_in_text)/len(no_of):.0f}%)")
print(f"=> total ongoing records with an NDC available somehow: {len(recs)-len(no_of)+len(ndc_in_text)} ({100*(len(recs)-len(no_of)+len(ndc_in_text))/len(recs):.0f}%)")

# what do the no-NDC leftovers look like?
print("\nSample ongoing records with NO NDC anywhere:")
for r in [r for r in no_of if not NDC.search(r.get("product_description",""))][:6]:
    print("  -", r["product_description"][:120].replace("\n"," "))

# distribution: institutional vs consumer signals
print("\nHow often does product_description mention hospital-type packaging?")
inst = sum(1 for r in recs if re.search(r"injection|vial|infusion|bag|syringe|IV\b|for intravenous", r.get("product_description",""), re.I))
print(f"  injectable/IV-looking: {inst} of {len(recs)} ({100*inst/len(recs):.0f}%)")

# lot number formats
print("\nSample code_info values (lot formats vary):")
for r in recs[:400:50]:
    print("  -", r.get("code_info","")[:100].replace("\n"," "))

# distribution_pattern
print("\nTop distribution_pattern values:")
for v, c in collections.Counter(r.get("distribution_pattern","").strip()[:40] for r in recs).most_common(8):
    print(f"  {c:>5}  {v!r}")

# size: how big is a full ongoing record set?
print(f"\nJSON size of all ongoing records: {len(json.dumps(recs))/1e6:.1f} MB")
