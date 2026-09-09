# Continuous floor exits

Intermediate clears keep player control, shooting, pickup and siphoning active.
Combat time and score are finalized once. A white exit marker opens at the safe
exterior entrance, with a small directional arrow near the player and a latch
sound. There is no intermediate report modal or Enter requirement.

Crossing within 12px after leaving its 24px safety radius triggers departure.
The 0.75s grace period prevents immediate transfer on the final kill. Pause,
disabled/dead players, and duplicate requests cannot trigger another transfer.
Resources are captured again on departure so post-clear scavenging counts.

The next seeded venue is requested asynchronously on clear without advancing
the run. Departure advances once and uses the shared fade; a loading failure
restores progression and controls. The last of six floors retains the final
summary. Existing safe deployment and room activation govern the next floor.

Regression: trigger safety + actual clear/scavenge/walk/transition/checkpoint
resource inheritance, deployment, and room visibility. The exit currently reuses
the entrance rather than adding a new architectural staircase to every venue.
