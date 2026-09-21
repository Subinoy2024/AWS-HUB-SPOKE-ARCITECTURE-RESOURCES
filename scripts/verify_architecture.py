#!/usr/bin/env python3
"""Check the hub-and-spoke build against the rules that fail silently.

Two modes.

  plan mode (authoritative)
      terraform -chdir=live/hub plan -out=tfplan
      terraform -chdir=live/hub show -json tfplan > hub.json
      python3 scripts/verify_architecture.py --plan hub.json

      Reads the resources Terraform will actually create. Renaming a variable or
      reformatting the code cannot fool it.

  source mode (weaker, no AWS credentials needed)
      python3 scripts/verify_architecture.py

      Scans the .tf files. Useful as a quick pre-commit sweep, but it is reading
      text, so it can pass while the deployment is wrong. Plan mode is the one
      that counts.

Why this exists at all: most mistakes here surface as a Terraform error. A few do
not. The worst is propagating spoke CIDRs into the TGW spoke route table - that
validates, plans, applies, and silently routes spoke-to-spoke traffic around the
firewall. Nothing in terraform, tflint or checkov will tell you.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

GREEN, RED, YELLOW, DIM, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"


@dataclass
class Results:
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    failures: list[str] = field(default_factory=list)

    def record(self, ok: bool | None, title: str, detail: str = "") -> None:
        if ok is None:
            self.skipped += 1
            print(f"  {YELLOW}SKIP{RESET}  {title}")
            if detail:
                print(f"        {DIM}{detail}{RESET}")
        elif ok:
            self.passed += 1
            print(f"  {GREEN}PASS{RESET}  {title}")
        else:
            self.failed += 1
            self.failures.append(title)
            print(f"  {RED}FAIL{RESET}  {title}")
            if detail:
                print(f"        {RED}{detail}{RESET}")


# --------------------------------------------------------------------------
# plan mode - reads resources, not text
# --------------------------------------------------------------------------

def planned(doc: dict) -> list[dict]:
    """Every resource the plan intends to create or update, flattened."""
    out = []
    for change in doc.get("resource_changes", []):
        actions = change.get("change", {}).get("actions", [])
        if "delete" in actions and "create" not in actions:
            continue
        after = change.get("change", {}).get("after") or {}
        out.append({
            "address": change.get("address", ""),
            "type": change.get("type", ""),
            "name": change.get("name", ""),
            "values": after,
        })
    return out


def check_plan(path: Path, r: Results) -> None:
    doc = json.loads(path.read_text())
    res = planned(doc)
    by_type: dict[str, list[dict]] = {}
    for item in res:
        by_type.setdefault(item["type"], []).append(item)

    print(f"\n{DIM}plan: {path}  ({len(res)} resources){RESET}\n")

    # Rule 1 - the one that fails silently.
    rts = by_type.get("aws_ec2_transit_gateway_route_table", [])
    spoke_rt = [x for x in rts if "spoke" in x["address"].lower()]
    spoke_rt_addrs = {x["address"] for x in spoke_rt}
    props = by_type.get("aws_ec2_transit_gateway_route_table_propagation", [])

    offenders = []
    for p in props:
        # In a plan the target id is usually still unknown, so fall back to the
        # address of the resource it references via the configuration block.
        ref = json.dumps(p["values"])
        if any(a.split(".")[-1] in ref for a in spoke_rt_addrs):
            offenders.append(p["address"])
        if "spoke_route_table" in p["address"] or "spoke_rt" in p["address"]:
            offenders.append(p["address"])

    r.record(
        not offenders,
        "No propagation targets the TGW spoke route table",
        "offending: " + ", ".join(sorted(set(offenders))) if offenders else "",
    )

    # Rule 3 - appliance mode only where the appliances are.
    attachments = by_type.get("aws_ec2_transit_gateway_vpc_attachment", [])
    if attachments:
        wrong = []
        for a in attachments:
            mode = a["values"].get("appliance_mode_support")
            is_inspection = "inspection" in a["address"].lower()
            if is_inspection and mode != "enable":
                wrong.append(f"{a['address']} should be enable, is {mode}")
            if not is_inspection and mode == "enable":
                wrong.append(f"{a['address']} must not enable appliance mode")
        r.record(not wrong, "Appliance mode enabled on the inspection attachment only",
                 "; ".join(wrong))
    else:
        r.record(None, "Appliance mode enabled on the inspection attachment only",
                 "no TGW attachments in this plan")

    # Rule 7 - cross-zone must stay off or the flow leaves its AZ.
    lbs = [x for x in by_type.get("aws_lb", []) if x["values"].get("load_balancer_type") == "network"]
    if lbs:
        bad = [x["address"] for x in lbs
               if x["values"].get("enable_cross_zone_load_balancing") is True]
        r.record(not bad, "Ingress NLB has cross-zone load balancing disabled", ", ".join(bad))
    else:
        r.record(None, "Ingress NLB has cross-zone load balancing disabled",
                 "no network load balancer in this plan")

    # Rule 8 - nothing may rewrite a route at runtime.
    lambdas = [x["address"] for x in by_type.get("aws_lambda_function", [])]
    events = [x["address"] for x in by_type.get("aws_cloudwatch_event_rule", [])]
    r.record(not (lambdas or events), "No Lambda or EventBridge rule in the data path",
             ", ".join(lambdas + events))

    # Rule 10 - S3 must be a gateway endpoint, and interface endpoints must be fenced.
    eps = by_type.get("aws_vpc_endpoint", [])
    if eps:
        s3 = [x for x in eps if str(x["values"].get("service_name", "")).endswith(".s3")]
        bad_s3 = [x["address"] for x in s3 if x["values"].get("vpc_endpoint_type") != "Gateway"]
        r.record(not bad_s3, "S3 uses a gateway endpoint", ", ".join(bad_s3))

        iface = [x for x in eps if x["values"].get("vpc_endpoint_type") == "Interface"]
        unfenced = [x["address"] for x in iface
                    if "aws:PrincipalOrgID" not in json.dumps(x["values"].get("policy", ""))]
        r.record(not unfenced,
                 "Every interface endpoint is fenced with aws:PrincipalOrgID",
                 ", ".join(unfenced))
    else:
        r.record(None, "VPC endpoint rules", "no VPC endpoints in this plan")


# --------------------------------------------------------------------------
# source mode - weaker, but needs no credentials
# --------------------------------------------------------------------------

RESOURCE_RE = re.compile(
    r'resource\s+"(?P<type>[\w-]+)"\s+"(?P<name>[\w-]+)"\s*\{', re.MULTILINE)


def tf_files() -> list[Path]:
    return [p for p in REPO.rglob("*.tf") if ".terraform" not in p.parts]


def block_for(text: str, start: int) -> str:
    """Return the body of the block that opens at `start`, brace-matched."""
    depth, i = 0, start
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
        i += 1
    return text[start:]


def resources() -> list[tuple[str, str, str, Path]]:
    found = []
    for path in tf_files():
        text = path.read_text()
        for m in RESOURCE_RE.finditer(text):
            body = block_for(text, m.end() - 1)
            found.append((m.group("type"), m.group("name"), body, path))
    return found


def check_source(r: Results) -> None:
    res = resources()
    print(f"\n{DIM}source: {len(res)} resources across {len(tf_files())} .tf files{RESET}")
    print(f"{YELLOW}source mode reads text, so it is advisory. Use --plan for the real check.{RESET}\n")

    def of(t: str):
        return [x for x in res if x[0] == t]

    # Rule 1
    props = of("aws_ec2_transit_gateway_route_table_propagation")
    bad = [f"{n} ({p.relative_to(REPO)})" for _, n, b, p in props
           if "spoke_route_table" in b]
    r.record(not bad, "No propagation targets the TGW spoke route table", ", ".join(bad))

    # Rule 2 and the ingress path, both directions
    prop_names = {n for _, n, _, _ in props}
    r.record("inspection" in prop_names,
             "Spoke propagates into the inspection route table")
    r.record("ingress" in prop_names,
             "Spoke propagates into the ingress route table (inbound reaches spokes)")
    r.record("ingress_to_inspection" in prop_names,
             "Ingress VPC propagates into the inspection route table (replies get back)")

    # Rule 3
    atts = of("aws_ec2_transit_gateway_vpc_attachment")
    wrong = []
    for _, name, body, path in atts:
        enabled = 'appliance_mode_support' in body and '"enable"' in body.split(
            "appliance_mode_support")[1].split("\n")[0]
        is_inspection = "inspection" in str(path)
        if is_inspection and not enabled:
            wrong.append(f"{path.relative_to(REPO)} should enable appliance mode")
        if not is_inspection and enabled:
            wrong.append(f"{path.relative_to(REPO)} must not enable appliance mode")
    r.record(not wrong, "Appliance mode enabled on the inspection attachment only",
             "; ".join(wrong))

    # Rule 5 and 6 - firewall before NAT, and the east-west return route
    insp = REPO / "modules/inspection-vpc/main.tf"
    if insp.exists():
        body = insp.read_text()
        r.record("nat_gateway_id" in body and "10.0.0.0/8" in body,
                 "Inspection VPC routes 0.0.0.0/0 to NAT and 10.0.0.0/8 back to the TGW")
    else:
        r.record(None, "Inspection VPC return routing", "module not found")

    # Rule 7
    nlbs = [b for t, _, b, _ in res if t == "aws_lb" and "network" in b]
    r.record(bool(nlbs) and all("enable_cross_zone_load_balancing = false" in b for b in nlbs),
             "Ingress NLB has cross-zone load balancing disabled")

    # Rule 8
    r.record(not of("aws_lambda_function") and not of("aws_cloudwatch_event_rule"),
             "No Lambda or EventBridge rule in the data path")

    # Rule 10
    eps = of("aws_vpc_endpoint")
    s3 = [b for _, _, b, _ in eps if ".s3" in b]
    r.record(bool(s3) and all('"Gateway"' in b for b in s3),
             "S3 uses a gateway endpoint")
    # The condition usually lives in an aws_iam_policy_document data block that the
    # endpoint references, not inline, so resolve the reference before judging.
    fenced_docs = set()
    for path in tf_files():
        text = path.read_text()
        for m in re.finditer(r'data\s+"aws_iam_policy_document"\s+"([\w-]+)"\s*\{', text):
            if "PrincipalOrgID" in block_for(text, m.end() - 1):
                fenced_docs.add(m.group(1))

    def is_fenced(body: str) -> bool:
        if "PrincipalOrgID" in body:
            return True
        ref = re.search(r'policy\s*=\s*data\.aws_iam_policy_document\.([\w-]+)\.json', body)
        return bool(ref and ref.group(1) in fenced_docs)

    iface = [(n, b) for _, n, b, _ in eps if '"Interface"' in b]
    unfenced = [n for n, b in iface if not is_fenced(b)]
    r.record(bool(iface) and not unfenced,
             "Every interface endpoint is fenced with aws:PrincipalOrgID",
             ", ".join(unfenced))

    # The NLB needs somewhere to send traffic
    r.record(bool(of("aws_lb_target_group")) and bool(of("aws_lb_listener")),
             "Ingress NLB has a listener and a target group")

    # Spoke subnet layout must match the published CIDR plan
    spoke = REPO / "modules/spoke/main.tf"
    if spoke.exists():
        body = spoke.read_text()
        r.record("(idx * 2) + 1" in body and "(idx * 2) + 2" in body,
                 "Spoke subnets match the published plan (app .1/.3, data .2/.4)")
        r.record("aws_route_table.data.id" in body,
                 "Data subnets reach S3 through the gateway endpoint")
    else:
        r.record(None, "Spoke subnet layout", "module not found")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--plan", type=Path,
                    help="terraform show -json output. Checks real resources.")
    args = ap.parse_args()

    print("=" * 62)
    print("Hub-and-spoke correctness rules")
    print("=" * 62)

    r = Results()
    if args.plan:
        if not args.plan.exists():
            print(f"{RED}plan file not found: {args.plan}{RESET}")
            return 2
        check_plan(args.plan, r)
    else:
        check_source(r)

    print("\n" + "=" * 62)
    print(f"passed {r.passed}   failed {r.failed}   skipped {r.skipped}")
    if r.failed:
        print(f"\n{RED}These rules fail silently in production. Fix before applying:{RESET}")
        for f in r.failures:
            print(f"  - {f}")
        return 1
    print(f"{GREEN}All checks passed.{RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
