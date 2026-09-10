# Retired: Bulwark

This four-tree class is **retired**. The talent system is now a global spec pool with three slots. See [docs/talents/system.md](../talents/system.md).

Bulwark split into:

- [Ironclad](../specs/aegis.md) — Plate + Grudge. Ultimate **Iron Rampage**.
- [Holdfast](../specs/bastion.md) — Rampart + Oath. Ultimate **Hearthguard**.

Do not plan or implement new Bulwark trees. Live `ClassCatalog` still has the old four-tree `bulwark` until an implement request. HP, threat, and DR rules moved to the system doc. NPC `bulwark_kit.gd` stays as-is until asked.
