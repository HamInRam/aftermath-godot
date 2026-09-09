# 100 room combat compositions

The catalog now has 100 base IDs: 48 existing authored formations plus 52
explicit coordinate plans in `utility/expanded_room_compositions.gd`. New plans
cover atrium, library, lounge, archive, kitchen, warehouse, salon, workshop,
chapel, foyer, studio, vault and terrace tactical themes. These names describe
combat compositions, not new bespoke art assets or external building footprints.

Each composition carries four enemy anchors, four patrol headings, a role mix
and two or three destructible cover anchors. Eight rotations/mirrors are
additional orientation variants, never counted toward the 100 base IDs.
The existing 12 venue building shells, connections and exterior entrances stay
intact. Per-venue object materials still determine the visible furniture.

Selection shuffles the complete pool without replacement, alternating combat
patterns where possible. A scene-entry nonce changes the layout on each fresh
entry, including a death retry. Cover generation and enemy generation share that
nonce for the entire instance. `room_run_seed_override` bypasses the nonce for
repeatable debugging. Loadout checkpoints and resource inheritance are unchanged.
This re-deals modules inside existing room sockets; it is NOT a new algorithm
that randomly reconnects exterior walls, door portals, or 100 standalone maps.

Current restrained 18–24 enemy/floor cap, at most two perimeter fill props/room,
local room alerts and automatic walking exits remain in force.

Tests cover catalog ID/composition uniqueness, 800 transformed anchor sets,
non-repeating 100-card draws, repeatability with explicit seeds, changing entry
seeds, 12 venue geometry/navigation, door passage and real retry/floor transfer.
These are automated checks, not a claim that all 100 rooms received manual
playtesting or that arbitrary door-graph permutations are supported.
