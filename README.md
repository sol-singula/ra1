# Mystery Morph Restaurant — Game Design Document

Design and development specification for **Mystery Morph Restaurant**, a Roblox restaurant-chaos /
creature-collection / tycoon game. Everything should be just a little bit ridiculous.

## The deliverable

**[`MYSTERY_MORPH_RESTAURANT_GDD.md`](MYSTERY_MORPH_RESTAURANT_GDD.md)** is the complete, assembled GDD:
40 numbered sections (vision → systems → technical architecture → roadmap/QA → content databases →
definition of done), a generated completion manifest, and a full table of contents.

The file is large (several MB), so GitHub may show it as raw text. To read one section at a time, use the
index below — each link opens that section's source file, which renders normally.

## Playable base (Roblox Studio)

[`game/`](game/README.md) is a Rojo project with the first playable slice: a greybox restaurant where you take
orders, cook at real stations, serve customers, handle angry ones, earn money, level up and upgrade. See
[`game/README.md`](game/README.md) to run it in Studio.

## Gameplay previews

[`gdd/previews/`](gdd/previews/README.md) has 52 captioned mock screenshots (title screen, HUD, ordering, every cooking
station, tantrums and combat, morph customization, shops, build mode, staff, offline earnings, Morph City and events).

## Section index

<!-- sections:start -->
| Section | Source file | Size |
|---|---|---|
| 1. Executive Summary | [`01_executive_summary.md`](gdd/sections/01_executive_summary.md) | 14 KB |
| 2. Game Vision | [`02_game_vision.md`](gdd/sections/02_game_vision.md) | 22 KB |
| 3. Design Pillars | [`03_design_pillars.md`](gdd/sections/03_design_pillars.md) | 25 KB |
| 4. Core Gameplay Loops | [`04_core_gameplay_loops.md`](gdd/sections/04_core_gameplay_loops.md) | 43 KB |
| 5. Cooking Mechanics | [`05_cooking_mechanics.md`](gdd/sections/05_cooking_mechanics.md) | 112 KB |
| 6. Recipe Database | [`06_recipe_database.md`](gdd/sections/06_recipe_database.md) | 343 KB |
| 6.18 Ridiculous Order Modifications | [`06b_order_modifications.md`](gdd/sections/06b_order_modifications.md) | 46 KB |
| 7. Ingredient Database | [`07_ingredient_database.md`](gdd/sections/07_ingredient_database.md) | 62 KB |
| 8. Customer AI | [`08_customer_ai.md`](gdd/sections/08_customer_ai.md) | 59 KB |
| 9. Customer Personalities | [`09_customer_personalities.md`](gdd/sections/09_customer_personalities.md) | 82 KB |
| 10. Satisfaction and Tantrum Systems | [`10_satisfaction_tantrum.md`](gdd/sections/10_satisfaction_tantrum.md) | 50 KB |
| 11. Combat System | [`11_combat_system.md`](gdd/sections/11_combat_system.md) | 78 KB |
| 12. Mutation System | [`12_mutation_system.md`](gdd/sections/12_mutation_system.md) | 62 KB |
| 12.9 Morph Combinations | [`12b_combinations_synergies.md`](gdd/sections/12b_combinations_synergies.md) | 40 KB |
| 13. Morph Customization | [`13_morph_customization.md`](gdd/sections/13_morph_customization.md) | 66 KB |
| 14. Player Progression | [`14_player_progression.md`](gdd/sections/14_player_progression.md) | 75 KB |
| 15. Restaurant Building | [`15_restaurant_building.md`](gdd/sections/15_restaurant_building.md) | 68 KB |
| 16. Employee Management | [`16_employee_management.md`](gdd/sections/16_employee_management.md) | 61 KB |
| 17. Offline Restaurant Simulation | [`17_offline_simulation.md`](gdd/sections/17_offline_simulation.md) | 82 KB |
| 18. Morph City | [`18_morph_city.md`](gdd/sections/18_morph_city.md) | 85 KB |
| 19. City NPCs | [`19_city_npcs.md`](gdd/sections/19_city_npcs.md) | 75 KB |
| 20. Quests | [`20_quests.md`](gdd/sections/20_quests.md) | 99 KB |
| 21. Multiplayer | [`21_multiplayer.md`](gdd/sections/21_multiplayer.md) | 54 KB |
| 22. Economy | [`22_economy.md`](gdd/sections/22_economy.md) | 74 KB |
| 23. Monetization | [`23_monetization.md`](gdd/sections/23_monetization.md) | 24 KB |
| 24. UI/UX | [`24_ui_ux.md`](gdd/sections/24_ui_ux.md) | 103 KB |
| 25. Art Direction | [`25_art_direction.md`](gdd/sections/25_art_direction.md) | 64 KB |
| 26. Animation and Audio | [`26_animation_audio.md`](gdd/sections/26_animation_audio.md) | 45 KB |
| 27. Roblox Architecture | [`27_roblox_architecture.md`](gdd/sections/27_roblox_architecture.md) | 144 KB |
| 28. Data Persistence | [`28_data_persistence.md`](gdd/sections/28_data_persistence.md) | 95 KB |
| 29. Security and Anti-Exploit | [`29_security_anti_exploit.md`](gdd/sections/29_security_anti_exploit.md) | 46 KB |
| 30. Performance Optimization | [`30_performance_optimization.md`](gdd/sections/30_performance_optimization.md) | 28 KB |
| 31. Analytics | [`31_analytics.md`](gdd/sections/31_analytics.md) | 46 KB |
| 32. Tutorial | [`32_tutorial.md`](gdd/sections/32_tutorial.md) | 72 KB |
| 33. Content Expansion | [`33_content_expansion.md`](gdd/sections/33_content_expansion.md) | 24 KB |
| 34. Development Roadmap | [`34_development_roadmap.md`](gdd/sections/34_development_roadmap.md) | 57 KB |
| 35. Testing and QA | [`35_testing_qa.md`](gdd/sections/35_testing_qa.md) | 69 KB |
| 36. Content Database Appendices | [`36_00_index.md`](gdd/sections/36_00_index.md) | 12 KB |
| 36.2 Recipe Quick Reference | [`36_02_recipe_quick_reference.md`](gdd/sections/36_02_recipe_quick_reference.md) | 35 KB |
| 36.3 Mutation Parts Database | [`36_03_mutation_parts.md`](gdd/sections/36_03_mutation_parts.md) | 140 KB |
| 36.4 Mutation Synergies Database | [`36_04_mutation_synergies.md`](gdd/sections/36_04_mutation_synergies.md) | 41 KB |
| 36.5 Morph Combination Examples | [`36_05_morph_combinations.md`](gdd/sections/36_05_morph_combinations.md) | 31 KB |
| 36.6 Ability Database | [`36_06_abilities.md`](gdd/sections/36_06_abilities.md) | 45 KB |
| 36.7 Status Effects Database | [`36_07_status_effects.md`](gdd/sections/36_07_status_effects.md) | 10 KB |
| 36.8 Employee Archetypes Database | [`36_08_employee_archetypes.md`](gdd/sections/36_08_employee_archetypes.md) | 40 KB |
| 36.9 Offline Incidents Database | [`36_09_offline_incidents.md`](gdd/sections/36_09_offline_incidents.md) | 20 KB |
| 36.10 City Buildings Database | [`36_10_city_buildings.md`](gdd/sections/36_10_city_buildings.md) | 47 KB |
| 36.11 City Events Database | [`36_11_city_events.md`](gdd/sections/36_11_city_events.md) | 41 KB |
| 36.12 Restaurant Tiers and Upgrades Database | [`36_12_restaurant_tiers_upgrades.md`](gdd/sections/36_12_restaurant_tiers_upgrades.md) | 36 KB |
| 36.13 Furniture and Equipment Catalog | [`36_13_furniture_catalog.md`](gdd/sections/36_13_furniture_catalog.md) | 47 KB |
| 36.14 Animation Library | [`36_14_animation_library.md`](gdd/sections/36_14_animation_library.md) | 44 KB |
| 36.15 Sound Library | [`36_15_sound_library.md`](gdd/sections/36_15_sound_library.md) | 41 KB |
| 36.16 Achievements Database | [`36_16_achievements.md`](gdd/sections/36_16_achievements.md) | 20 KB |
| 36.17 Progression Milestones Database | [`36_17_milestones.md`](gdd/sections/36_17_milestones.md) | 11 KB |
| 37. Implementation Checklists | [`37_implementation_checklists.md`](gdd/sections/37_implementation_checklists.md) | 26 KB |
| 38. Open Design Decisions | [`38_open_design_decisions.md`](gdd/sections/38_open_design_decisions.md) | 12 KB |
| 39. Balancing Assumptions | [`39_balancing_assumptions.md`](gdd/sections/39_balancing_assumptions.md) | 33 KB |
| 40. Definition of Done | [`40_definition_of_done.md`](gdd/sections/40_definition_of_done.md) | 14 KB |
| Appendix A. Design Canon | [`canon.md`](gdd/canon.md) | 103 KB |
<!-- sections:end -->

## Repository layout

| Path | Purpose |
|---|---|
| `MYSTERY_MORPH_RESTAURANT_GDD.md` | Assembled document (generated — do not edit by hand) |
| `gdd/brief/MASTER_PROMPT.md` | The client brief the GDD answers |
| `gdd/canon.md` | Single source of truth for identifiers, master content lists, constants and core formulas that every section uses |
| `gdd/sections/*.md` | Section sources, assembled in filename order |
| `gdd/data/*.json` | Data-backed content (recipes, ingredients, mutation parts, …) — also the intended source for generated Luau data modules (§27) |
| `gdd/tools/render_*.py` | Render data-backed tables from `gdd/data/` into section files |
| `gdd/tools/validate_gdd.py` | Validates section order, identifier cross-references, content counts, canonical names and required diagrams |
| `gdd/tools/build_gdd.py` | Validates, generates the front matter (manifest + TOC) and assembles the GDD |
| `game/` | Playable Roblox base: Rojo project, Luau source, tests (see its README) |
| `gdd/previews/` | 52 mock gameplay screenshots (GUI, ordering, cooking, shops, building, city) — see its README |
| `gdd/tools/compose_previews*.py`, `render_previews.js` | Build the preview GUI overlays and render them over the background plates |

## Rebuilding

Python 3.10+ (standard library only):

```bash
python3 gdd/tools/validate_gdd.py          # report; exit code 1 on any failure
python3 gdd/tools/build_gdd.py --render    # re-render data tables, validate, assemble the GDD
```

Edit section sources or `gdd/data/*.json`, never the assembled file.
