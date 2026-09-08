class_name NeonPalette
extends RefCounted

const INK := Color("0d0d0d")
const DEEP_SHADOW := Color("242424")
const PAPER := Color("dcdcdc")
# The active OTXO-inspired contract permits only grayscale structure plus the
# one immutable blood crimson. Legacy semantic names remain API-compatible but
# no longer leak blue, green, gold or magenta into gameplay.
const CYAN := Color("d8d8d8")
const MAGENTA := Color("a0a0a0")
const ACID := Color("bcbcbc")
const AMBER := Color("eeeeee")
## Blood has one immutable presentation color.  Keep the old names as aliases so
## combat callers cannot accidentally reintroduce age/weapon based tinting.
const BLOOD_CRIMSON := Color("c7072d")
const BLOOD_FRESH := BLOOD_CRIMSON
const BLOOD_DARK := BLOOD_CRIMSON

## Corpse anatomy belongs to the monochrome world palette.  Crimson is reserved
## exclusively for liquid blood emitted by a living enemy impact.
const TISSUE := Color("858585")
const BONE := Color("e2e2e2")
const SKIN := Color("b8b8b8")
