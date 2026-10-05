title="a clean change"
developer_did="adds giftWrapFee() with a doc comment and behaviour-named tests (scenario 00)"
rule=""
file="src/pricing.js"
apply() {
  . ./proof/scenarios/00-clean-change.sh
  apply
}
