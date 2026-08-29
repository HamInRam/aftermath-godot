# AFTERMATH 1.2 low-pixel world redesign

All campaign floors use an 8x8 tile grid, 8x8/16x16 props, hard pixel edges and a maximum of six colors per prop. Detail comes from room purpose, silhouette and sparse transparent wear overlays rather than dense texture.

| Case | Functional rooms | Combat identity | Cleanup identity |
|---|---|---|---|
| Nightclub | security foyer, lounge, dance floor, VIP, backstage, washrooms | glass sight lines, central crossfire, two service flanks | broken bottles, cables, bar and DJ equipment |
| Sandwich Shop | dining room, service counter, kitchen, cold store, office | short counter peeks and kitchen choke points | grease, paper waste, appliances and food-service fixtures |
| After Hours | west range, central range, control rooms, south service wing | surveillance lanes and deliberate training-room crossfire | evidence cabinets, consoles and widely separated rinse/disposal points |
| Harbor Exchange | warehouse, loading lane, exchange room, dock | long cargo lanes cut by crate cover | oil, hazard markings, cargo and water/dumpster disposal split |
| Room Service | north rooms, central corridor, south rooms, reception | repeated door breaches with windowed corridor exposure | scattered papers, room furniture and two-ended disposal route |
| Penthouse | lounge, private suite, glass gallery, bar, service rooms | open luxury spaces versus narrow service flank | fragile glass, valuables and furniture restoration |
| Cold Storage | west freezer, cold core, east storage, machinery bays | three parallel refrigerated lanes | drains, freezer racks and industrial grime |
| Casino Floor | entry cage, gaming floor, central roulette, VIP cage | circular cover clusters and guarded cage exits | machines, glass, paper/chips and bar fixtures |
| Police Archive | records, archive hub, evidence lockup | shelf lanes, cameras and fixed sentry positions | case files, evidence cabinets and restricted disposal route |
| Slaughterhouse | intake, processing, packing and cold room | horizontal production lanes and conveyor choke points | drains, machinery, grime and incinerator routing |
| Broadcast Tower | service hall, studio, control room and equipment bay | camera-covered studio approaches and control-room flank | cables, consoles, equipment cabinets and recording evidence |
| Last Call | entry, ruined main club, final stage, VIP and back service | a compressed remix of campaign lessons with multiple breach routes | shattered club equipment, finale evidence and long return path |

## Destruction contract

- Every authored prop has intact, damaged, destroyed-debris and restored states.
- Bullets, melee attacks, thrown weapons and dangerous door swings can damage props.
- Destroyed props release their navigation cell; restored props occupy it again.
- Property destruction is recorded in mission forensics and creates an optional cleanup interaction.
- Signature landmarks use the same combat/cleanup contract instead of remaining decorative scenery.
