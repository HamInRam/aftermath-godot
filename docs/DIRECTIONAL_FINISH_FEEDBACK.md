# Directional combat feedback

- Player shotgun/sniper trigger pulls use 1.65x their existing authored camera
  impulse. Execution uses 4 world pixels, received health damage 2.8 pixels away
  from the source. Enemy firing alone does not move the player's camera.
- Directional displacement is capped at 4 world pixels. Strongest impulse wins
  within a physics tick; weaker pellet/kill feedback cannot reverse the heavy
  shot. An analytic critically damped return (omega 13) is frame-rate independent.
  Secondary noise follows the impact axis, with quarter-strength lateral noise.
- Actual enemy death tests its authored room membership. Last living member gives
  a 60 ms finisher; combo milestones 10/20/30... give 50 ms. One finisher per second,
  sharing the existing 100 ms per rolling second hit-stop budget. A same-impact
  pause may be upgraded within 20 ms, not followed by a second stacked pause.
- Finisher edge shader pulses white then black for 180 ms, leaving the center
  transparent. It is hidden at rest, ignores mouse input, uses real-time tweening,
  and respects flash intensity. Camera shake and hit-stop settings still apply.
- Ballistics, player turn rate, damage, blood mass and particle counts are unchanged.

Validation: directional_finish_feedback, critical_hit_stop, feedback_hierarchy,
shotgun_blood_feedback, roguelike_floor_flow and living_knockback. The hierarchy
test retains an existing shutdown resource warning. Real-renderer shotgun review
checks the production firing/death/corpse path; the directional test also verifies
edge-versus-center pixel brightness when launched with the real renderer.
