"""Poke at the openFDA drug enforcement API to see what recall records look like.

Run with:  python3 tools/explore_openfda.py
No dependencies beyond the Python standard library. Findings are summarised in
docs/openfda-notes.md.
"""
import json, urllib.request, urllib.parse, collections, textwrap

BASE = "https://api.fda.gov/drug/enforcement.json"

def q(params):
    url = BASE + "?" + urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        return {"error": e.code, "results": [], "meta": {"results": {"total": 0}}}

# ---- 1. Overall shape of the dataset ----
total = q({"search": "report_date:[20000101 TO 20991231]", "limit": 1})["meta"]["results"]["total"]
ongoing = q({"search": "status:Ongoing", "limit": 1})["meta"]["results"]["total"]
with_openfda = q({"search": "_exists_:openfda.generic_name", "limit": 1})["meta"]["results"]["total"]
ongoing_with_openfda = q({"search": "status:Ongoing AND _exists_:openfda.generic_name", "limit": 1})["meta"]["results"]["total"]
print(f"Total drug enforcement records: {total}")
print(f"  Ongoing: {ongoing}")
print(f"  With openfda.generic_name: {with_openfda} ({100*with_openfda/total:.0f}%)")
print(f"  Ongoing AND with openfda.generic_name: {ongoing_with_openfda} ({100*ongoing_with_openfda/ongoing:.0f}% of ongoing)")

print("\nClassification breakdown (ongoing):")
for b in q({"search": "status:Ongoing", "count": "classification.exact"})["results"]:
    print(f"  {b['term']}: {b['count']}")

print("\nRecall initiation year (all):")
yr = collections.Counter()
for b in q({"count": "recall_initiation_date"})["results"]:
    yr[b["time"][:4]] += b["count"]
for y in sorted(yr)[-6:]:
    print(f"  {y}: {yr[y]}")

# ---- 2. Per-drug: how do common meds show up? ----
DRUGS = ["metformin", "lisinopril", "atorvastatin", "levothyroxine", "amlodipine", "losartan", "ibuprofen", "acetaminophen"]
print("\nPer-drug matches (text search on product_description vs. structured openfda.generic_name):")
print(f"  {'drug':<15}{'text/all':>10}{'text/ongoing':>14}{'openfda/all':>13}{'openfda/ongoing':>17}")
for d in DRUGS:
    t_all = q({"search": f'product_description:"{d}"', "limit": 1})["meta"]["results"]["total"]
    t_on  = q({"search": f'product_description:"{d}" AND status:Ongoing', "limit": 1})["meta"]["results"]["total"]
    o_all = q({"search": f'openfda.generic_name:"{d}"', "limit": 1})["meta"]["results"]["total"]
    o_on  = q({"search": f'openfda.generic_name:"{d}" AND status:Ongoing', "limit": 1})["meta"]["results"]["total"]
    print(f"  {d:<15}{t_all:>10}{t_on:>14}{o_all:>13}{o_on:>17}")

# ---- 3. Look at actual records ----
def show(rec):
    of = rec.get("openfda", {})
    print("  " + "-"*70)
    for k in ["recall_number", "status", "classification", "recall_initiation_date", "report_date", "recalling_firm", "voluntary_mandated"]:
        print(f"  {k:<24}{rec.get(k)}")
    print(f"  {'product_description':<24}" + textwrap.shorten(rec.get("product_description",""), 300))
    print(f"  {'reason_for_recall':<24}" + textwrap.shorten(rec.get("reason_for_recall",""), 300))
    print(f"  {'code_info (lots)':<24}" + textwrap.shorten(rec.get("code_info",""), 200))
    print(f"  {'product_quantity':<24}{rec.get('product_quantity')}")
    print(f"  {'distribution_pattern':<24}" + textwrap.shorten(rec.get("distribution_pattern",""), 120))
    print(f"  {'openfda.brand_name':<24}{of.get('brand_name')}")
    print(f"  {'openfda.generic_name':<24}{of.get('generic_name')}")
    print(f"  {'openfda.product_ndc':<24}{of.get('product_ndc')}")

print("\n\nSample ONGOING metformin records (text match, newest first):")
for r in q({"search": 'product_description:"metformin" AND status:Ongoing', "sort": "recall_initiation_date:desc", "limit": 3})["results"]:
    show(r)

print("\n\nMost recent ongoing Class I recalls (the ones that matter most):")
for r in q({"search": 'status:Ongoing AND classification:"Class I"', "sort": "recall_initiation_date:desc", "limit": 3})["results"]:
    show(r)

# ---- 4. How noisy is text matching? ----
print("\n\nText-match noise check: records matching 'lisinopril' whose openfda.generic_name does NOT contain lisinopril:")
n = 0
for r in q({"search": 'product_description:"lisinopril" AND _exists_:openfda.generic_name', "limit": 100})["results"]:
    g = " ".join(r.get("openfda", {}).get("generic_name", [])).lower()
    if "lisinopril" not in g:
        n += 1
        print("  -", textwrap.shorten(r["product_description"], 110), "| generic:", g[:60])
print(f"  ({n} noisy of 100 checked)")
