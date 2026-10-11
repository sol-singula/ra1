# MYSTERY MORPH RESTAURANT

**Game Design Document & Roblox Development Specification**

> *Serve. Cook. Upgrade. Survive.* — Everything should be just a little bit ridiculous.

| Field | Value |
|---|---|
| Document | `MYSTERY_MORPH_RESTAURANT_GDD.md` |
| Version | 1.0 (assembled 2026-10-11) |
| Platform | Roblox (Luau), desktop · tablet · mobile · console |
| Audience | Players aged ~8–16, with depth for older players |
| Genre | Restaurant sim · cooking chaos · creature collection · character customization · action combat · tycoon · social · idle economy |
| Sources | `gdd/sections/*.md` (prose), `gdd/data/*.json` (data-backed tables), `gdd/canon.md` (identifiers and constants), `gdd/brief/MASTER_PROMPT.md` (client brief) |

## How to Use This Document

- **Forty numbered sections** follow the structure required by the brief. Sections 1–4 explain the game, 5–26 specify every gameplay system, 27–31 are the technical specification, 32–35 cover onboarding, expansion, roadmap and QA, 36 holds the content databases, and 37–40 hold checklists, open decisions, balancing assumptions and the definition of done.
- **Identifiers** are stable, unique and cross-referenced everywhere (`RCP_BRG_001`, `MUT_216`, `ABL_018`, `EMP_001`, `QST_TUT_006` …). An identifier in the first column of a table row (or leading a heading) is the entity's *definition*; every other mention is a *reference* and resolves to exactly one definition. The full prefix list is in §36.1.
- **`[TUNABLE]`** marks a balancing assumption: implement it as stated (systems depend on it) but expose it in configuration so it can be tuned with telemetry. §39 consolidates them.
- **Acceptance criteria** are numbered `AC-<section>-<n>` and are measurable; §40 defines how they roll up into "done".
- **Cross-references** use `§N` (section) and `§N.M` (subsection).
- **Databases:** recipes §6, ingredients §7, personalities §9, NPCs §19, quests §20; everything else in §36.
- **Canon references** (`canon C4.4`, `§C4.4`, `E1`–`E14`) point to Appendix A, the Design Canon: the shared identifiers, constants, formulas and edge-case rulings every section builds on.

## Completion Manifest

Generated automatically by `gdd/tools/build_gdd.py` from the validator, so the counts below are counted from this document and are never typed by hand.

**Automated validation:** ✅ PASS — 2,693 defined identifiers, 25,263 identifier references, **0 unresolved**, 0 canonical-name mismatches, 40 Mermaid diagrams. Re-run with `python3 gdd/tools/validate_gdd.py`.

#### Content counts

| Requirement | Minimum | Delivered | Status | Location |
|---|---|---|---|---|
| Recipes (≥150 across ≥15 categories) | 150 | 150 | ✅ | §6, §36.2 |
| Ingredients (complete; all canon core IDs) | 48 | 167 | ✅ | §7 |
| Order modifications (≥75) | 75 | 93 | ✅ | §6.18 |
| Kitchen stations (all 22 brief stations + 2 late-game) | 24 | 24 | ✅ | §5 |
| Customer personalities (≥30) | 30 | 32 | ✅ | §9 |
| Abilities (≥50 combat) | 70 | 70 | ✅ | §36.6 |
| Status effects | 20 | 20 | ✅ | §36.7 |
| Mutation parts (≥250) | 250 | 280 | ✅ | §36.3 |
| Mutation synergies (≥75) | 75 | 141 | ✅ | §36.4 |
| Morph combination examples (≥100) | 100 | 130 | ✅ | §36.5 |
| Chef skill-tree upgrades (≥20) | 20 | 22 | ✅ | §14 |
| Combat skill-tree upgrades (≥20) | 20 | 22 | ✅ | §14 |
| Repair skill-tree upgrades (≥20) | 20 | 22 | ✅ | §14 |
| Customer-service specialization nodes | 10 | 12 | ✅ | §14 |
| Employee-management specialization nodes | 10 | 12 | ✅ | §14 |
| Restaurant tiers (≥10) | 10 | 10 | ✅ | §15, §36.12 |
| Furniture & equipment (≥100 purchasable) | 100 | 214 | ✅ | §36.13 |
| Trophy decorations | 10 | 10 | ✅ | §36.13 |
| Restaurant upgrades | 40 | 73 | ✅ | §36.12 |
| Employee roles (12) | 12 | 12 | ✅ | §16, §36.1 |
| Employee archetypes (≥75) | 75 | 97 | ✅ | §36.8 |
| Offline incidents (≥50) | 50 | 69 | ✅ | §36.9 |
| City districts (≥10) | 10 | 10 | ✅ | §18, §36.1 |
| City buildings (≥16) | 16 | 22 | ✅ | §36.10 |
| Named NPCs (≥100) | 100 | 115 | ✅ | §19 |
| Quests (≥100) | 100 | 157 | ✅ | §20 |
| City events (≥30) | 30 | 32 | ✅ | §36.11 |
| Animations (≥150) | 150 | 235 | ✅ | §36.14 |
| Sound effects | 100 | 201 | ✅ | §36.15 |
| Music tracks | 10 | 36 | ✅ | §36.15 |
| Achievements | 50 | 88 | ✅ | §36.16 |
| Progression milestones | 30 | 54 | ✅ | §36.17 |
| Recipe categories (≥15) | 15 | 15 | ✅ | §6 |

#### Required diagrams

| Diagram | Key | Status | Source file |
|---|---|---|---|
| Core gameplay loop | `core-gameplay-loop` | ✅ | 04_core_gameplay_loops.md |
| Customer state machine | `customer-state-machine` | ✅ | 08_customer_ai.md |
| Cooking workflow | `cooking-workflow` | ✅ | 05_cooking_mechanics.md |
| Combat state machine | `combat-state-machine` | ✅ | 11_combat_system.md |
| Employee management | `employee-management` | ✅ | 16_employee_management.md |
| Offline earnings calculation | `offline-earnings` | ✅ | 17_offline_simulation.md |
| Player progression | `player-progression` | ✅ | 14_player_progression.md |
| Roblox service architecture | `service-architecture` | ✅ | 27_roblox_architecture.md |
| Data persistence flow | `data-persistence-flow` | ✅ | 28_data_persistence.md |

#### Sections

| # | Section | Status |
|---|---|---|
| 1 | Executive Summary | ✅ |
| 2 | Game Vision | ✅ |
| 3 | Design Pillars | ✅ |
| 4 | Core Gameplay Loops | ✅ |
| 5 | Cooking Mechanics | ✅ |
| 6 | Recipe Database | ✅ |
| 7 | Ingredient Database | ✅ |
| 8 | Customer AI | ✅ |
| 9 | Customer Personalities | ✅ |
| 10 | Satisfaction and Tantrum Systems | ✅ |
| 11 | Combat System | ✅ |
| 12 | Mutation System | ✅ |
| 13 | Morph Customization | ✅ |
| 14 | Player Progression | ✅ |
| 15 | Restaurant Building | ✅ |
| 16 | Employee Management | ✅ |
| 17 | Offline Restaurant Simulation | ✅ |
| 18 | Morph City | ✅ |
| 19 | City NPCs | ✅ |
| 20 | Quests | ✅ |
| 21 | Multiplayer | ✅ |
| 22 | Economy | ✅ |
| 23 | Monetization | ✅ |
| 24 | UI/UX | ✅ |
| 25 | Art Direction | ✅ |
| 26 | Animation and Audio | ✅ |
| 27 | Roblox Architecture | ✅ |
| 28 | Data Persistence | ✅ |
| 29 | Security and Anti-Exploit | ✅ |
| 30 | Performance Optimization | ✅ |
| 31 | Analytics | ✅ |
| 32 | Tutorial | ✅ |
| 33 | Content Expansion | ✅ |
| 34 | Development Roadmap | ✅ |
| 35 | Testing and QA | ✅ |
| 36 | Content Database Appendices | ✅ |
| 37 | Implementation Checklists | ✅ |
| 38 | Open Design Decisions | ✅ |
| 39 | Balancing Assumptions | ✅ |
| 40 | Definition of Done | ✅ |

<details><summary>Source files, size, acceptance criteria and [TUNABLE] markers per file</summary>

| Source file | Size (KB) | Acceptance criteria | [TUNABLE] markers |
|---|---|---|---|
| `gdd/sections/01_executive_summary.md` | 14 | 5 | 18 |
| `gdd/sections/02_game_vision.md` | 22 | 5 | 5 |
| `gdd/sections/03_design_pillars.md` | 25 | 5 | 17 |
| `gdd/sections/04_core_gameplay_loops.md` | 43 | 10 | 12 |
| `gdd/sections/05_cooking_mechanics.md` | 112 | 26 | 2 |
| `gdd/sections/06_recipe_database.md` | 343 | 12 | 6 |
| `gdd/sections/06b_order_modifications.md` | 46 | 16 | 2 |
| `gdd/sections/07_ingredient_database.md` | 62 | 8 | 8 |
| `gdd/sections/08_customer_ai.md` | 59 | 16 | 14 |
| `gdd/sections/09_customer_personalities.md` | 82 | 14 | 1 |
| `gdd/sections/10_satisfaction_tantrum.md` | 50 | 16 | 6 |
| `gdd/sections/11_combat_system.md` | 78 | 24 | 9 |
| `gdd/sections/12_mutation_system.md` | 62 | 16 | 8 |
| `gdd/sections/12b_combinations_synergies.md` | 40 | 13 | 7 |
| `gdd/sections/13_morph_customization.md` | 66 | 15 | 4 |
| `gdd/sections/14_player_progression.md` | 75 | 21 | 13 |
| `gdd/sections/15_restaurant_building.md` | 68 | 22 | 8 |
| `gdd/sections/16_employee_management.md` | 61 | 15 | 7 |
| `gdd/sections/17_offline_simulation.md` | 82 | 17 | 6 |
| `gdd/sections/18_morph_city.md` | 85 | 24 | 9 |
| `gdd/sections/19_city_npcs.md` | 75 | 14 | 4 |
| `gdd/sections/20_quests.md` | 99 | 17 | 8 |
| `gdd/sections/21_multiplayer.md` | 54 | 25 | 10 |
| `gdd/sections/22_economy.md` | 74 | 20 | 9 |
| `gdd/sections/23_monetization.md` | 24 | 17 | 0 |
| `gdd/sections/24_ui_ux.md` | 103 | 32 | 11 |
| `gdd/sections/25_art_direction.md` | 64 | 23 | 2 |
| `gdd/sections/26_animation_audio.md` | 45 | 20 | 2 |
| `gdd/sections/27_roblox_architecture.md` | 144 | 25 | 11 |
| `gdd/sections/28_data_persistence.md` | 95 | 20 | 12 |
| `gdd/sections/29_security_anti_exploit.md` | 46 | 15 | 5 |
| `gdd/sections/30_performance_optimization.md` | 28 | 14 | 2 |
| `gdd/sections/31_analytics.md` | 46 | 14 | 3 |
| `gdd/sections/32_tutorial.md` | 72 | 17 | 6 |
| `gdd/sections/33_content_expansion.md` | 24 | 8 | 5 |
| `gdd/sections/34_development_roadmap.md` | 57 | 38 | 5 |
| `gdd/sections/35_testing_qa.md` | 69 | 12 | 6 |
| `gdd/sections/36_00_index.md` | 12 | 0 | 0 |
| `gdd/sections/36_02_recipe_quick_reference.md` | 35 | 0 | 0 |
| `gdd/sections/36_03_mutation_parts.md` | 140 | 0 | 1 |
| `gdd/sections/36_04_mutation_synergies.md` | 41 | 0 | 8 |
| `gdd/sections/36_05_morph_combinations.md` | 31 | 0 | 0 |
| `gdd/sections/36_06_abilities.md` | 45 | 0 | 0 |
| `gdd/sections/36_07_status_effects.md` | 10 | 0 | 0 |
| `gdd/sections/36_08_employee_archetypes.md` | 40 | 0 | 1 |
| `gdd/sections/36_09_offline_incidents.md` | 20 | 0 | 1 |
| `gdd/sections/36_10_city_buildings.md` | 47 | 15 | 13 |
| `gdd/sections/36_11_city_events.md` | 41 | 14 | 2 |
| `gdd/sections/36_12_restaurant_tiers_upgrades.md` | 36 | 0 | 2 |
| `gdd/sections/36_13_furniture_catalog.md` | 47 | 0 | 1 |
| `gdd/sections/36_14_animation_library.md` | 44 | 0 | 0 |
| `gdd/sections/36_15_sound_library.md` | 41 | 0 | 0 |
| `gdd/sections/36_16_achievements.md` | 20 | 0 | 1 |
| `gdd/sections/36_17_milestones.md` | 11 | 0 | 0 |
| `gdd/sections/37_implementation_checklists.md` | 26 | 17 | 1 |
| `gdd/sections/38_open_design_decisions.md` | 12 | 3 | 0 |
| `gdd/sections/39_balancing_assumptions.md` | 33 | 6 | 2 |
| `gdd/sections/40_definition_of_done.md` | 14 | 13 | 2 |
| **Total** | **3342** | **699** | **298** |

</details>

## Brief Coverage Map

| Brief Part | Where it is answered |
|---|---|
| 1 Game Identity | §1 Executive Summary, §2 Game Vision, §3 Design Pillars |
| 2 Gameplay Loops (5 timescales, offline) | §4 Core Gameplay Loops, §17 |
| 3 Cooking System | §5 Cooking Mechanics |
| 4 Recipe & Food Database, 4.16 Modifications | §6 (6.1–6.17), §6.18, §7, §36.2 |
| 5 Customer AI & Behavior | §8, §9, §10 |
| 6 Combat System | §11, §36.6, §36.7 |
| 7 Morph System | §12 (12.1–12.10), §36.3, §36.4, §36.5 |
| 8 Morph Customization Interface | §13 |
| 9 Player Progression | §14, §36.16, §36.17 |
| 10 Restaurant Building & Upgrades | §15, §36.12, §36.13 |
| 11 Employees & Offline Operations | §16, §17, §36.8, §36.9 |
| 12 Morph City | §18, §19, §36.10, §36.11 |
| 13 Quests & Missions | §20 |
| 14 Multiplayer | §21 |
| 15 Economy | §22 |
| 16 Monetization | §23 |
| 17 User Interface | §24 (plus §13 morph screen, §17 Welcome Back screen) |
| 18 Art Direction, Animation, Sound | §25, §26, §36.14, §36.15 |
| 19 Roblox Technical Architecture | §27, §28, §29, §30 |
| 20 Analytics & Retention | §31 |
| 21 Tutorial / FTUE | §32 |
| 22 Content Expansion | §33 |
| 23 Complete Content Databases | §36 (index in §36.1) plus §6, §7, §9, §19, §20 |
| 24 Development Roadmap | §34 |
| 25 Testing & QA | §35 |
| 26 Cross-cutting Requirements | §3 (Cross-Cutting Design Requirements) and every system section |
| 27 Output Structure | This document: 40 numbered sections in the required order |
| 28 Execution Instructions | Completion Manifest (below), gdd/tools/validate_gdd.py |

## Table of Contents

- [1. Executive Summary](#1-executive-summary)
  - [1.1 The Pitch](#11-the-pitch)
  - [1.2 Key Facts](#12-key-facts)
  - [1.3 Unique Selling Points](#13-unique-selling-points)
  - [1.4 The Core Loop](#14-the-core-loop)
  - [1.5 Monetization Stance](#15-monetization-stance)
  - [1.6 MVP vs Launch (summary; schedule in §34)](#16-mvp-vs-launch-summary-schedule-in-34)
  - [1.7 KPI Targets [TUNABLE]](#17-kpi-targets-tunable)
  - [1.8 Document Map: How to Read This GDD](#18-document-map-how-to-read-this-gdd)
  - [1.9 Acceptance Criteria](#19-acceptance-criteria)
- [2. Game Vision](#2-game-vision)
  - [2.1 Player Fantasy](#21-player-fantasy)
  - [2.2 Morph City: Setting and Lore](#22-morph-city-setting-and-lore)
  - [2.3 Tone Bible](#23-tone-bible)
  - [2.4 Audience Segments](#24-audience-segments)
  - [2.5 "Everything Should Be Just a Little Bit Ridiculous", System by System](#25-everything-should-be-just-a-little-bit-ridiculous-system-by-system)
  - [2.6 What This Game Is NOT](#26-what-this-game-is-not)
  - [2.7 Mechanical Inspirations (genres and mechanics only, nothing copied)](#27-mechanical-inspirations-genres-and-mechanics-only-nothing-copied)
  - [2.8 The Player's Arc: Broken Burger Shack → Legendary Mutation Restaurant](#28-the-players-arc-broken-burger-shack--legendary-mutation-restaurant)
  - [2.9 Design Laws (the Creative Director Notes, formalized)](#29-design-laws-the-creative-director-notes-formalized)
  - [2.10 Acceptance Criteria](#210-acceptance-criteria)
- [3. Design Pillars](#3-design-pillars)
  - [3.1 Pillar Overview](#31-pillar-overview)
  - [3.2 The Seven Pillars](#32-the-seven-pillars)
  - [3.3 How the Pillars Reinforce Each Other](#33-how-the-pillars-reinforce-each-other)
  - [3.4 Cross-Cutting Design Requirements (brief Part 26)](#34-cross-cutting-design-requirements-brief-part-26)
  - [3.5 Acceptance Criteria](#35-acceptance-criteria)
- [4. Core Gameplay Loops](#4-core-gameplay-loops)
  - [4.1 Immediate Loop (15–60 s)](#41-immediate-loop-1560-s)
  - [4.2 Short Session (5–15 min)](#42-short-session-515-min)
  - [4.3 Medium Session (15–45 min)](#43-medium-session-1545-min)
  - [4.4 Long-Term Progression](#44-long-term-progression)
  - [4.5 Offline Progression (the player's perspective)](#45-offline-progression-the-players-perspective)
  - [4.6 Loop Interconnection and Economy Flow](#46-loop-interconnection-and-economy-flow)
  - [4.7 Dependencies, Roblox Implementation and Edge Cases](#47-dependencies-roblox-implementation-and-edge-cases)
  - [4.8 Acceptance Criteria](#48-acceptance-criteria)
- [5. Cooking Mechanics](#5-cooking-mechanics)
  - [5.1 Design Analysis — Why Kitchen Chaos Is Fun](#51-design-analysis--why-kitchen-chaos-is-fun)
  - [5.2 Interaction Model](#52-interaction-model)
  - [5.3 Station Specifications](#53-station-specifications)
  - [5.4 Preparation Actions](#54-preparation-actions)
  - [5.5 Quality Scoring](#55-quality-scoring)
  - [5.6 Orders & Tickets](#56-orders--tickets)
  - [5.7 Kitchen Hazards & Cleaning](#57-kitchen-hazards--cleaning)
  - [5.8 Co-op Cooking Rules (canon E7, E12)](#58-co-op-cooking-rules-canon-e7-e12)
  - [5.9 Cooking Workflow Diagram](#59-cooking-workflow-diagram)
  - [5.10 Roblox Implementation](#510-roblox-implementation)
  - [5.11 Edge Cases](#511-edge-cases)
  - [5.12 Acceptance Criteria](#512-acceptance-criteria)
- [6. Recipe Database](#6-recipe-database)
  - [6.1 Recipe System Rules](#61-recipe-system-rules)
  - [6.2 Pricing & Profitability](#62-pricing--profitability)
  - [6.3 Burgers (15)](#63-burgers-15)
  - [6.4 Pizza (15)](#64-pizza-15)
  - [6.5 Tacos & Mexican-Inspired (10)](#65-tacos--mexican-inspired-10)
  - [6.6 Sandwiches (10)](#66-sandwiches-10)
  - [6.7 Soups (10)](#67-soups-10)
  - [6.8 Pasta (10)](#68-pasta-10)
  - [6.9 Breakfast (10)](#69-breakfast-10)
  - [6.10 Desserts (15)](#610-desserts-15)
  - [6.11 Drinks & Smoothies (15)](#611-drinks--smoothies-15)
  - [6.12 Seafood (10)](#612-seafood-10)
  - [6.13 Salads (5)](#613-salads-5)
  - [6.14 Fried Foods (5)](#614-fried-foods-5)
  - [6.15 Alien Cuisine (10)](#615-alien-cuisine-10)
  - [6.16 Mutation Cuisine (5)](#616-mutation-cuisine-5)
  - [6.17 Legendary Dishes (5)](#617-legendary-dishes-5)
  - [6.18 Ridiculous Order Modifications](#618-ridiculous-order-modifications)
- [7. Ingredient Database](#7-ingredient-database)
  - [7.1 Ingredient System Rules](#71-ingredient-system-rules)
  - [7.2 Ingredient Tables](#72-ingredient-tables)
  - [7.3 Tag Index](#73-tag-index)
- [8. Customer AI](#8-customer-ai)
  - [8.1 Purpose](#81-purpose)
  - [8.2 Rules & Mechanics — Spawning and Arrival](#82-rules--mechanics--spawning-and-arrival)
  - [8.3 Rules & Mechanics — Procedural Appearance and Names](#83-rules--mechanics--procedural-appearance-and-names)
  - [8.4 Rules & Mechanics — The Customer State Machine](#84-rules--mechanics--the-customer-state-machine)
  - [8.5 Rules & Mechanics — Interruption Handling](#85-rules--mechanics--interruption-handling)
  - [8.6 Rules & Mechanics — Seating and Host Logic](#86-rules--mechanics--seating-and-host-logic)
  - [8.7 Rules & Mechanics — Navigation](#87-rules--mechanics--navigation)
  - [8.8 Rules & Mechanics — Ordering](#88-rules--mechanics--ordering)
  - [8.9 Rules & Mechanics — Waiting and Patience](#89-rules--mechanics--waiting-and-patience)
  - [8.10 Rules & Mechanics — Receiving, Inspecting, Eating](#810-rules--mechanics--receiving-inspecting-eating)
  - [8.11 Rules & Mechanics — Paying, Tipping, Leaving](#811-rules--mechanics--paying-tipping-leaving)
  - [8.12 Rules & Mechanics — Regulars](#812-rules--mechanics--regulars)
  - [8.13 Variables](#813-variables)
  - [8.14 UI](#814-ui)
  - [8.15 Progression](#815-progression)
  - [8.16 Player Interactions](#816-player-interactions)
  - [8.17 Dependencies](#817-dependencies)
  - [8.18 Roblox Implementation](#818-roblox-implementation)
  - [8.19 Edge Cases](#819-edge-cases)
  - [8.20 Acceptance Criteria](#820-acceptance-criteria)
- [9. Customer Personalities](#9-customer-personalities)
  - [9.1 Purpose](#91-purpose)
  - [9.2 Rules & Mechanics — How Personalities Layer on Bodies](#92-rules--mechanics--how-personalities-layer-on-bodies)
  - [9.3 Personality Summary Table](#93-personality-summary-table)
  - [9.4 Personality Detail Blocks](#94-personality-detail-blocks)
  - [9.5 Variables](#95-variables)
  - [9.6 UI](#96-ui)
  - [9.7 Progression](#97-progression)
  - [9.8 Player Interactions](#98-player-interactions)
  - [9.9 Dependencies](#99-dependencies)
  - [9.10 Roblox Implementation](#910-roblox-implementation)
  - [9.11 Edge Cases](#911-edge-cases)
  - [9.12 Acceptance Criteria](#912-acceptance-criteria)
- [10. Satisfaction and Tantrum Systems](#10-satisfaction-and-tantrum-systems)
  - [10.1 Purpose](#101-purpose)
  - [10.2 Rules & Mechanics — The Satisfaction Formula](#102-rules--mechanics--the-satisfaction-formula)
  - [10.3 Rules & Mechanics — Personality, Mutation and Event Modifiers](#103-rules--mechanics--personality-mutation-and-event-modifiers)
  - [10.4 Worked Satisfaction Examples](#104-worked-satisfaction-examples)
  - [10.5 Rules & Mechanics — Payment, Tips and Reputation](#105-rules--mechanics--payment-tips-and-reputation)
  - [10.6 Rules & Mechanics — The Anger Meter](#106-rules--mechanics--the-anger-meter)
  - [10.7 Rules & Mechanics — Escalation Rolls and Behavior by Level](#107-rules--mechanics--escalation-rolls-and-behavior-by-level)
  - [10.8 Rules & Mechanics — Chain Reactions (Emergent Chaos)](#108-rules--mechanics--chain-reactions-emergent-chaos)
  - [10.9 Rules & Mechanics — Level 6: Restaurant-wide Chaos](#109-rules--mechanics--level-6-restaurant-wide-chaos)
  - [10.10 Rules & Mechanics — De-escalation and Recovery](#1010-rules--mechanics--de-escalation-and-recovery)
  - [10.11 Rules & Mechanics — Consequences and Fairness Safeguards](#1011-rules--mechanics--consequences-and-fairness-safeguards)
  - [10.12 Variables](#1012-variables)
  - [10.13 UI — Color-Independent Indicators](#1013-ui--color-independent-indicators)
  - [10.14 Progression](#1014-progression)
  - [10.15 Player Interactions](#1015-player-interactions)
  - [10.16 Dependencies](#1016-dependencies)
  - [10.17 Roblox Implementation](#1017-roblox-implementation)
  - [10.18 Edge Cases](#1018-edge-cases)
  - [10.19 Acceptance Criteria](#1019-acceptance-criteria)
- [11. Combat System](#11-combat-system)
  - [11.1 Purpose & Design Goals](#111-purpose--design-goals)
  - [11.2 Who Fights Whom (Hostility Model)](#112-who-fights-whom-hostility-model)
  - [11.3 Controls & Input (per device)](#113-controls--input-per-device)
  - [11.4 Targeting](#114-targeting)
  - [11.5 Core Combat Rules](#115-core-combat-rules)
  - [11.6 Environmental Combat](#116-environmental-combat)
  - [11.7 Physics Limits & Performance Safeguards](#117-physics-limits--performance-safeguards)
  - [11.8 NPC Combat AI](#118-npc-combat-ai)
  - [11.9 Mutation-Based Combat](#119-mutation-based-combat)
  - [11.10 Defeat & Recovery](#1110-defeat--recovery)
  - [11.11 Co-op & PvP Adjustments](#1111-co-op--pvp-adjustments)
  - [11.12 Combat State Machine](#1112-combat-state-machine)
  - [11.13 UI & Feedback](#1113-ui--feedback)
  - [11.14 Progression & Rewards Hooks](#1114-progression--rewards-hooks)
  - [11.15 Dependencies](#1115-dependencies)
  - [11.16 Roblox Implementation](#1116-roblox-implementation)
  - [11.17 Edge Cases](#1117-edge-cases)
  - [11.18 Acceptance Criteria](#1118-acceptance-criteria)
- [12. Mutation System](#12-mutation-system)
  - [12.1 Overview](#121-overview)
  - [12.2 Anatomy Slots and Compatibility](#122-anatomy-slots-and-compatibility)
  - [12.3 Attaching Parts to Roblox R15 Rigs](#123-attaching-parts-to-roblox-r15-rigs)
  - [12.4 The 16 Mutation Categories](#124-the-16-mutation-categories)
  - [12.5 Rarities and Acquisition](#125-rarities-and-acquisition)
  - [12.6 Upgrades](#126-upgrades)
  - [12.7 Procedural Generation and the Combination System](#127-procedural-generation-and-the-combination-system)
  - [12.8 Balance Limits](#128-balance-limits)
  - [12.9 Morph Combinations](#129-morph-combinations)
  - [12.10 Mutation Synergy Rules](#1210-mutation-synergy-rules)
- [13. Morph Customization](#13-morph-customization)
  - [13.1 Purpose & Design Goals](#131-purpose--design-goals)
  - [13.2 Entry Points, Blocking Rules & Screen States](#132-entry-points-blocking-rules--screen-states)
  - [13.3 Layouts & Wireframes](#133-layouts--wireframes)
  - [13.4 ScreenGui Component Hierarchy](#134-screengui-component-hierarchy)
  - [13.5 Rotatable 3D Preview (ViewportFrame + WorldModel)](#135-rotatable-3d-preview-viewportframe--worldmodel)
  - [13.6 Body-Part Categories (canon C13.1 UI groups)](#136-body-part-categories-canon-c131-ui-groups)
  - [13.7 Mutation Inventory Grid](#137-mutation-inventory-grid)
  - [13.8 Equipped Panel, Equip / Unequip Controls & Slot Rules](#138-equipped-panel-equip--unequip-controls--slot-rules)
  - [13.9 Rarity Indicators (canon C13.3)](#139-rarity-indicators-canon-c133)
  - [13.10 Stats Panel & Compare Deltas](#1310-stats-panel--compare-deltas)
  - [13.11 Ability Descriptions & Synergy Preview](#1311-ability-descriptions--synergy-preview)
  - [13.12 Saved Loadouts & Switching Rules](#1312-saved-loadouts--switching-rules)
  - [13.13 Morph Naming](#1313-morph-naming)
  - [13.14 Cosmetic Color Selection (Style tab)](#1314-cosmetic-color-selection-style-tab)
  - [13.15 Mutation Upgrade Controls (Upgrade tab)](#1315-mutation-upgrade-controls-upgrade-tab)
  - [13.16 Entry to Lab Fusion (`BLD_11`) and Body Mods (`BLD_02`)](#1316-entry-to-lab-fusion-bld_11-and-body-mods-bld_02)
  - [13.17 Show-Off Features](#1317-show-off-features)
  - [13.18 Accessibility](#1318-accessibility)
  - [13.19 Controller Navigation Map](#1319-controller-navigation-map)
  - [13.20 Remotes & Server Validation](#1320-remotes--server-validation)
  - [13.21 Data Model (fields the Morph screen reads and writes; schema owned by §28)](#1321-data-model-fields-the-morph-screen-reads-and-writes-schema-owned-by-28)
  - [13.22 Performance](#1322-performance)
  - [13.23 Dependencies](#1323-dependencies)
  - [13.24 Edge Cases](#1324-edge-cases)
  - [13.25 Acceptance Criteria](#1325-acceptance-criteria)
- [14. Player Progression](#14-player-progression)
  - [14.1 Purpose and Progression Philosophy](#141-purpose-and-progression-philosophy)
  - [14.2 Progression Layers](#142-progression-layers)
  - [14.3 Level System](#143-level-system)
  - [14.4 Level Table (1–100)](#144-level-table-1100)
  - [14.5 XP Sources](#145-xp-sources)
  - [14.6 Long-Term Pacing (brief 2.4)](#146-long-term-pacing-brief-24)
  - [14.7 Player Statistics](#147-player-statistics)
  - [14.8 Health (HP)](#148-health-hp)
  - [14.9 Skill Trees — Rules & Mechanics](#149-skill-trees--rules--mechanics)
  - [14.10 Chef Tree (`SKL_CHEF_`)](#1410-chef-tree-skl_chef_)
  - [14.11 Combat Tree (`SKL_CMBT_`)](#1411-combat-tree-skl_cmbt_)
  - [14.12 Repair Tree (`SKL_RPR_`)](#1412-repair-tree-skl_rpr_)
  - [14.13 Specializations — Customer Service (`SKL_SVC_`) and Employee Management (`SKL_MGMT_`)](#1413-specializations--customer-service-skl_svc_-and-employee-management-skl_mgmt_)
  - [14.14 Skill-Point Economy (choices are mandatory)](#1414-skill-point-economy-choices-are-mandatory)
  - [14.15 Respec Rules](#1415-respec-rules)
  - [14.16 Progression Flow (diagram)](#1416-progression-flow-diagram)
  - [14.17 Player Interactions and Dependencies](#1417-player-interactions-and-dependencies)
  - [14.18 Roblox Implementation](#1418-roblox-implementation)
  - [14.19 Edge Cases](#1419-edge-cases)
  - [14.20 Acceptance Criteria](#1420-acceptance-criteria)
- [15. Restaurant Building](#15-restaurant-building)
  - [15.1 Purpose and Design Goals](#151-purpose-and-design-goals)
  - [15.2 Restaurant Tier Progression](#152-restaurant-tier-progression)
  - [15.3 Tier Upgrade Flow](#153-tier-upgrade-flow)
  - [15.4 Plot and Instanced Interior Model](#154-plot-and-instanced-interior-model)
  - [15.5 Building Placement System](#155-building-placement-system)
  - [15.6 Atmosphere Score (feeds `M` and `DecorMult`)](#156-atmosphere-score-feeds-m-and-decormult)
  - [15.7 Cleanliness (`K`)](#157-cleanliness-k)
  - [15.8 Themes and Sets](#158-themes-and-sets)
  - [15.9 Damage and Repair](#159-damage-and-repair)
  - [15.10 Station Upgrades (canon §C4.9)](#1510-station-upgrades-canon-c49)
  - [15.11 UI](#1511-ui)
  - [15.12 Roblox Implementation](#1512-roblox-implementation)
  - [15.13 Dependencies](#1513-dependencies)
  - [15.14 Edge Cases](#1514-edge-cases)
  - [15.15 Acceptance Criteria](#1515-acceptance-criteria)
- [16. Employee Management](#16-employee-management)
  - [16.1 Purpose](#161-purpose)
  - [16.2 Employee Roles](#162-employee-roles)
  - [16.3 Online Work AI](#163-online-work-ai)
  - [16.4 Employee Statistics](#164-employee-statistics)
  - [16.5 How Employee Mutations Shape Performance](#165-how-employee-mutations-shape-performance)
  - [16.6 Hiring System](#166-hiring-system)
  - [16.7 Employee Management](#167-employee-management)
  - [16.8 Variables [TUNABLE]](#168-variables-tunable)
  - [16.9 Progression and return on investment](#169-progression-and-return-on-investment)
  - [16.10 Player interactions](#1610-player-interactions)
  - [16.11 Dependencies](#1611-dependencies)
  - [16.12 Roblox implementation](#1612-roblox-implementation)
  - [16.13 Edge cases](#1613-edge-cases)
  - [16.14 Acceptance criteria](#1614-acceptance-criteria)
- [17. Offline Restaurant Simulation](#17-offline-restaurant-simulation)
  - [17.1 Purpose and principles](#171-purpose-and-principles)
  - [17.2 The return procedure](#172-the-return-procedure)
  - [17.3 Variables [TUNABLE]](#173-variables-tunable)
  - [17.4 The model in detail (elaborations of canon §C15) [TUNABLE]](#174-the-model-in-detail-elaborations-of-canon-c15-tunable)
  - [17.5 Deterministic RNG and hourly stepping](#175-deterministic-rng-and-hourly-stepping)
  - [17.6 Caps and the tuning plan [TUNABLE]](#176-caps-and-the-tuning-plan-tunable)
  - [17.7 Persistence and idempotency (canon §C15, E11)](#177-persistence-and-idempotency-canon-c15-e11)
  - [17.8 Anti-exploit](#178-anti-exploit)
  - [17.9 Worked examples](#179-worked-examples)
  - [17.10 Welcome Back screen](#1710-welcome-back-screen)
  - [17.11 Offline mutation progression [TUNABLE]](#1711-offline-mutation-progression-tunable)
  - [17.12 Analytics hooks](#1712-analytics-hooks)
  - [17.13 Edge cases](#1713-edge-cases)
  - [17.14 Acceptance criteria](#1714-acceptance-criteria)
- [18. Morph City](#18-morph-city)
  - [18.1 City Overview & Visual Hooks](#181-city-overview--visual-hooks)
  - [18.2 City Layout & District Map](#182-city-layout--district-map)
  - [18.3 District Specifications](#183-district-specifications)
  - [18.4 Travel](#184-travel)
  - [18.5 City Interactivity Catalog](#185-city-interactivity-catalog)
  - [18.6 Hidden Alleyways & Secrets](#186-hidden-alleyways--secrets)
  - [18.7 City NPC Presence Model](#187-city-npc-presence-model)
  - [18.8 City Event System](#188-city-event-system)
  - [18.9 Roblox Implementation](#189-roblox-implementation)
  - [18.10 Edge Cases](#1810-edge-cases)
  - [18.11 Acceptance Criteria](#1811-acceptance-criteria)
- [19. City NPCs](#19-city-npcs)
  - [19.1 Purpose](#191-purpose)
  - [19.2 Rules & Mechanics — the NPC data model](#192-rules--mechanics--the-npc-data-model)
  - [19.3 Dialogue trees (conditions, variables, effects)](#193-dialogue-trees-conditions-variables-effects)
  - [19.4 Interaction prompt rules](#194-interaction-prompt-rules)
  - [19.5 Idle schedules & behaviors](#195-idle-schedules--behaviors)
  - [19.6 Hearts — optional friendship (Progression · Player Interactions)](#196-hearts--optional-friendship-progression--player-interactions)
  - [19.7 Roblox Implementation — SPCV placement, streaming, performance](#197-roblox-implementation--spcv-placement-streaming-performance)
  - [19.8 Localization-ready dialogue keys](#198-localization-ready-dialogue-keys)
  - [19.9 NPC database (115 named NPCs)](#199-npc-database-115-named-npcs)
  - [19.10 Edge Cases](#1910-edge-cases)
  - [19.11 Dependencies](#1911-dependencies)
  - [19.12 Acceptance Criteria](#1912-acceptance-criteria)
- [20. Quests](#20-quests)
  - [20.1 Purpose](#201-purpose)
  - [20.2 Rules & Mechanics — quest types and lifecycle](#202-rules--mechanics--quest-types-and-lifecycle)
  - [20.3 Objective grammar (typed objectives)](#203-objective-grammar-typed-objectives)
  - [20.4 UI — journal, tracking, markers](#204-ui--journal-tracking-markers)
  - [20.5 Daily & weekly rotation and rerolls](#205-daily--weekly-rotation-and-rerolls)
  - [20.6 Variables — reward scaling [TUNABLE]](#206-variables--reward-scaling-tunable)
  - [20.7 Failure, abandon, retry — and Roblox implementation](#207-failure-abandon-retry--and-roblox-implementation)
  - [20.8 Progression — the story campaign "From Shack to Legendary"](#208-progression--the-story-campaign-from-shack-to-legendary)
  - [20.9 Quest database](#209-quest-database)
  - [20.10 Unlock & trophy map (quick reference)](#2010-unlock--trophy-map-quick-reference)
  - [20.11 Edge Cases](#2011-edge-cases)
  - [20.12 Dependencies](#2012-dependencies)
  - [20.13 Acceptance Criteria](#2013-acceptance-criteria)
- [21. Multiplayer](#21-multiplayer)
  - [21.1 Purpose and Social Pillars](#211-purpose-and-social-pillars)
  - [21.2 Server, Plot and Visit Model](#212-server-plot-and-visit-model)
  - [21.3 Co-op Roles and Permission Matrix](#213-co-op-roles-and-permission-matrix)
  - [21.4 Co-op Rewards](#214-co-op-rewards)
  - [21.5 Shared Cooking, Serving, Cleaning and Combat](#215-shared-cooking-serving-cleaning-and-combat)
  - [21.6 Anti-Grief and Anti-Theft](#216-anti-grief-and-anti-theft)
  - [21.7 Joining, Invites and Parties](#217-joining-invites-and-parties)
  - [21.8 Shared City](#218-shared-city)
  - [21.9 Arena PvP (strictly opt-in)](#219-arena-pvp-strictly-opt-in)
  - [21.10 Roblox Implementation](#2110-roblox-implementation)
  - [21.11 Edge Cases](#2111-edge-cases)
  - [21.12 Acceptance Criteria](#2112-acceptance-criteria)
- [22. Economy](#22-economy)
  - [22.1 Purpose and Economy Pillars](#221-purpose-and-economy-pillars)
  - [22.2 Currencies](#222-currencies)
  - [22.3 Revenue Sources](#223-revenue-sources)
  - [22.4 Money Sinks](#224-money-sinks)
  - [22.5 Active Income Model and Canon Calibration](#225-active-income-model-and-canon-calibration)
  - [22.6 Recipe Profitability](#226-recipe-profitability)
  - [22.7 Operating Margins](#227-operating-margins)
  - [22.8 Employee Return on Investment](#228-employee-return-on-investment)
  - [22.9 Upgrade Payback Periods](#229-upgrade-payback-periods)
  - [22.10 Mutation Acquisition Pacing](#2210-mutation-acquisition-pacing)
  - [22.11 Offline Earnings Summary (refer §17)](#2211-offline-earnings-summary-refer-17)
  - [22.12 Economy Simulations](#2212-economy-simulations)
  - [22.13 Mutation Shard and Research Token Flows](#2213-mutation-shard-and-research-token-flows)
  - [22.14 Inflation Controls](#2214-inflation-controls)
  - [22.15 Economy Telemetry and Alarm Thresholds](#2215-economy-telemetry-and-alarm-thresholds)
  - [22.16 Exploit Prevention and `EconomyService`](#2216-exploit-prevention-and-economyservice)
  - [22.17 Edge Cases](#2217-edge-cases)
  - [22.18 Acceptance Criteria](#2218-acceptance-criteria)
- [23. Monetization](#23-monetization)
  - [23.1 Purpose and Principles](#231-purpose-and-principles)
  - [23.2 Catalog and Robux Price Bands](#232-catalog-and-robux-price-bands)
  - [23.3 Morph Skins and Palettes](#233-morph-skins-and-palettes)
  - [23.4 Restaurant Themes and Decorative Furniture Packs](#234-restaurant-themes-and-decorative-furniture-packs)
  - [23.5 Emotes, Looks, VIP Visual Effects and Nonessential Customization](#235-emotes-looks-vip-visual-effects-and-nonessential-customization)
  - [23.6 Game Passes vs Developer Products](#236-game-passes-vs-developer-products)
  - [23.7 Exclusively Earnable — Never Sold for Robux](#237-exclusively-earnable--never-sold-for-robux)
  - [23.8 Paid Random Items: None](#238-paid-random-items-none)
  - [23.9 Premium Payouts](#239-premium-payouts)
  - [23.10 Revenue Expectations (hypotheses, to be validated)](#2310-revenue-expectations-hypotheses-to-be-validated)
  - [23.11 Roblox Implementation](#2311-roblox-implementation)
  - [23.12 Edge Cases](#2312-edge-cases)
  - [23.13 Acceptance Criteria](#2313-acceptance-criteria)
- [24. UI/UX](#24-uiux)
  - [24.1 System Summary](#241-system-summary)
  - [24.2 Design System](#242-design-system)
  - [24.3 Input Adaptation](#243-input-adaptation)
  - [24.4 Scaling, Layout Classes and Safe Areas](#244-scaling-layout-classes-and-safe-areas)
  - [24.5 UI Layering, Screen Stack and the UIController State Machine](#245-ui-layering-screen-stack-and-the-uicontroller-state-machine)
  - [24.6 Readability During Chaos](#246-readability-during-chaos)
  - [24.7 Accessibility Settings](#247-accessibility-settings)
  - [24.8 Controller Navigation Maps](#248-controller-navigation-maps)
  - [24.9 Mobile Button Cluster and Thumb Zones](#249-mobile-button-cluster-and-thumb-zones)
  - [24.10 Notification and Toast System](#2410-notification-and-toast-system)
  - [24.11 Localization Readiness](#2411-localization-readiness)
  - [24.12 UI Performance Budgets](#2412-ui-performance-budgets)
  - [24.13 Interface Specification Conventions](#2413-interface-specification-conventions)
  - [24.14 Main HUD (brief 17.1)](#2414-main-hud-brief-171)
  - [24.15 Restaurant Hub (brief 17.2)](#2415-restaurant-hub-brief-172)
  - [24.16 Morph Interface (brief 17.3) — summary; full spec in §13](#2416-morph-interface-brief-173--summary-full-spec-in-13)
  - [24.17 City Map (brief 17.4)](#2417-city-map-brief-174)
  - [24.18 Employee Interface (brief 17.5)](#2418-employee-interface-brief-175)
  - [24.19 Main Menu](#2419-main-menu)
  - [24.20 Tutorial Overlays](#2420-tutorial-overlays)
  - [24.21 Cooking Minigame Widgets](#2421-cooking-minigame-widgets)
  - [24.22 Restaurant Upgrades Screen](#2422-restaurant-upgrades-screen)
  - [24.23 Building Placement Mode](#2423-building-placement-mode)
  - [24.24 Repair Minigame](#2424-repair-minigame)
  - [24.25 Combat Abilities UI (bar, cooldowns, targeting)](#2425-combat-abilities-ui-bar-cooldowns-targeting)
  - [24.26 Quest Journal](#2426-quest-journal)
  - [24.27 Achievements](#2427-achievements)
  - [24.28 Inventory](#2428-inventory)
  - [24.29 Mutation Research (Lab Fusion)](#2429-mutation-research-lab-fusion)
  - [24.30 Marketplace (Cosmetic Shop)](#2430-marketplace-cosmetic-shop)
  - [24.31 Settings](#2431-settings)
  - [24.32 Stats & Level-Up Panel ("Level Up & Get Stronger") — summary; full spec in §14](#2432-stats--level-up-panel-level-up--get-stronger--summary-full-spec-in-14)
  - [24.33 Offline Earnings Report and Welcome Back Screen — summary; full spec in §17](#2433-offline-earnings-report-and-welcome-back-screen--summary-full-spec-in-17)
  - [24.34 Interface Coverage Matrix](#2434-interface-coverage-matrix)
  - [24.35 Acceptance Criteria](#2435-acceptance-criteria)
- [25. Art Direction](#25-art-direction)
  - [25.1 Visual Pillars](#251-visual-pillars)
  - [25.2 Visual Style](#252-visual-style)
  - [25.3 Character Art](#253-character-art)
  - [25.4 Restaurant Art](#254-restaurant-art)
  - [25.5 City Art](#255-city-art)
  - [25.6 VFX Guidelines](#256-vfx-guidelines)
  - [25.7 Asset Pipeline](#257-asset-pipeline)
  - [25.8 Edge Cases](#258-edge-cases)
  - [25.9 Acceptance Criteria](#259-acceptance-criteria)
- [26. Animation and Audio](#26-animation-and-audio)
  - [26.1 Scope and Ownership](#261-scope-and-ownership)
  - [26.2 Animation System](#262-animation-system)
  - [26.3 Audio System](#263-audio-system)
- [27. Roblox Architecture](#27-roblox-architecture)
  - [27.1 System Summary](#271-system-summary)
  - [27.2 Architecture Principles](#272-architecture-principles)
  - [27.3 Toolchain & Workflow](#273-toolchain--workflow)
  - [27.4 Project Structure](#274-project-structure)
  - [27.5 Content Data Pipeline](#275-content-data-pipeline)
  - [27.6 Service Framework](#276-service-framework)
  - [27.7 Networking Layer (`Net`)](#277-networking-layer-net)
  - [27.8 Core Services (§C19)](#278-core-services-c19)
  - [27.9 Client Controllers](#279-client-controllers)
  - [27.10 Service Architecture Diagram](#2710-service-architecture-diagram)
  - [27.11 Server Startup and Player Join](#2711-server-startup-and-player-join)
  - [27.12 Reference Implementations](#2712-reference-implementations)
  - [27.13 Server Tick Budgets and Scheduling](#2713-server-tick-budgets-and-scheduling)
  - [27.14 Scaling Notes (8 restaurants per server)](#2714-scaling-notes-8-restaurants-per-server)
  - [27.15 Feature Flags and Remote Configuration](#2715-feature-flags-and-remote-configuration)
  - [27.16 Edge-Case Ownership (§C22)](#2716-edge-case-ownership-c22)
  - [27.17 State Ownership, Persistence and Security Overview](#2717-state-ownership-persistence-and-security-overview)
  - [27.18 Acceptance Criteria](#2718-acceptance-criteria)
- [28. Data Persistence](#28-data-persistence)
  - [28.1 Purpose](#281-purpose)
  - [28.2 Rules & Mechanics (persistence invariants)](#282-rules--mechanics-persistence-invariants)
  - [28.3 Variables](#283-variables)
  - [28.4 UI](#284-ui)
  - [28.5 Progression](#285-progression)
  - [28.6 Player Interactions](#286-player-interactions)
  - [28.7 Dependencies](#287-dependencies)
  - [28.8 Roblox Implementation — DataStore Layout](#288-roblox-implementation--datastore-layout)
  - [28.9 Roblox Implementation — Profile Schema (typed Luau)](#289-roblox-implementation--profile-schema-typed-luau)
  - [28.10 Roblox Implementation — Size Budget vs the 4 MB Key Limit](#2810-roblox-implementation--size-budget-vs-the-4-mb-key-limit)
  - [28.11 Roblox Implementation — Compaction Encodings](#2811-roblox-implementation--compaction-encodings)
  - [28.12 Roblox Implementation — Schema Versioning and Ordered Migrations](#2812-roblox-implementation--schema-versioning-and-ordered-migrations)
  - [28.13 Roblox Implementation — Session Locking and Teleport Handoff](#2813-roblox-implementation--session-locking-and-teleport-handoff)
  - [28.14 Roblox Implementation — Load Pipeline (join)](#2814-roblox-implementation--load-pipeline-join)
  - [28.15 Roblox Implementation — Autosave and Save Triggers](#2815-roblox-implementation--autosave-and-save-triggers)
  - [28.16 Roblox Implementation — Retry Handling and Safe Mode (§C22 E6)](#2816-roblox-implementation--retry-handling-and-safe-mode-c22-e6)
  - [28.17 Roblox Implementation — Idempotent Transactions](#2817-roblox-implementation--idempotent-transactions)
  - [28.18 Roblox Implementation — Robux Purchases (`MarketplaceService.ProcessReceipt`)](#2818-roblox-implementation--robux-purchases-marketplaceserviceprocessreceipt)
  - [28.19 Roblox Implementation — Duplicate Reward Prevention](#2819-roblox-implementation--duplicate-reward-prevention)
  - [28.20 Roblox Implementation — Recovery from Interrupted Saves and Corruption](#2820-roblox-implementation--recovery-from-interrupted-saves-and-corruption)
  - [28.21 Roblox Implementation — Shutdown (`BindToClose`, §C22 E13)](#2821-roblox-implementation--shutdown-bindtoclose-c22-e13)
  - [28.22 Data Persistence Flow](#2822-data-persistence-flow)
  - [28.23 Roblox Implementation — DataStore Request-Budget Math (per server)](#2823-roblox-implementation--datastore-request-budget-math-per-server)
  - [28.24 Roblox Implementation — Data Erasure (Right to Be Forgotten)](#2824-roblox-implementation--data-erasure-right-to-be-forgotten)
  - [28.25 Edge Cases](#2825-edge-cases)
  - [28.26 Acceptance Criteria](#2826-acceptance-criteria)
- [29. Security and Anti-Exploit](#29-security-and-anti-exploit)
  - [29.1 Purpose](#291-purpose)
  - [29.2 Rules & Mechanics (security principles)](#292-rules--mechanics-security-principles)
  - [29.3 Variables](#293-variables)
  - [29.4 UI](#294-ui)
  - [29.5 Progression (escalation ladder)](#295-progression-escalation-ladder)
  - [29.6 Player Interactions](#296-player-interactions)
  - [29.7 Dependencies](#297-dependencies)
  - [29.8 Threat Model](#298-threat-model)
  - [29.9 Server-Authority Checklist](#299-server-authority-checklist)
  - [29.10 Remote Validation Framework](#2910-remote-validation-framework)
  - [29.11 Movement Validation (`MovementSanity`)](#2911-movement-validation-movementsanity)
  - [29.12 Combat Validation](#2912-combat-validation)
  - [29.13 Cooking Validation](#2913-cooking-validation)
  - [29.14 Economy Integrity and Anomaly Detection (`AnomalyMonitor`)](#2914-economy-integrity-and-anomaly-detection-anomalymonitor)
  - [29.15 Offline-Time and Clock Integrity](#2915-offline-time-and-clock-integrity)
  - [29.16 Co-op Griefing and Alt Farming](#2916-co-op-griefing-and-alt-farming)
  - [29.17 Logging, Moderation Tooling, Ban/Kick Policy](#2917-logging-moderation-tooling-bankick-policy)
  - [29.18 Exploit Test Cases](#2918-exploit-test-cases)
  - [29.19 Edge Cases](#2919-edge-cases)
  - [29.20 Acceptance Criteria](#2920-acceptance-criteria)
- [30. Performance Optimization](#30-performance-optimization)
  - [30.1 Purpose](#301-purpose)
  - [30.2 Rules & Mechanics (performance principles)](#302-rules--mechanics-performance-principles)
  - [30.3 Variables (master budget table)](#303-variables-master-budget-table)
  - [30.4 UI](#304-ui)
  - [30.5 Progression](#305-progression)
  - [30.6 Player Interactions](#306-player-interactions)
  - [30.7 Dependencies](#307-dependencies)
  - [30.8 Performance Budgets by Platform](#308-performance-budgets-by-platform)
  - [30.9 NPC Population and SPCV](#309-npc-population-and-spcv)
  - [30.10 Pathfinding Strategy](#3010-pathfinding-strategy)
  - [30.11 Physics Limits](#3011-physics-limits)
  - [30.12 Destruction Effects](#3012-destruction-effects)
  - [30.13 Morph Complexity and Impostor LOD](#3013-morph-complexity-and-impostor-lod)
  - [30.14 Animation Performance](#3014-animation-performance)
  - [30.15 Network Replication](#3015-network-replication)
  - [30.16 Asset Streaming](#3016-asset-streaming)
  - [30.17 Memory](#3017-memory)
  - [30.18 Object Pooling](#3018-object-pooling)
  - [30.19 Device Quality Tiers and Auto-Scaling](#3019-device-quality-tiers-and-auto-scaling)
  - [30.20 Profiling Workflow](#3020-profiling-workflow)
  - [30.21 Performance Test Plan](#3021-performance-test-plan)
  - [30.22 Edge Cases](#3022-edge-cases)
  - [30.23 Acceptance Criteria](#3023-acceptance-criteria)
- [31. Analytics](#31-analytics)
  - [31.1 Purpose](#311-purpose)
  - [31.2 Rules & Mechanics (analytics principles)](#312-rules--mechanics-analytics-principles)
  - [31.3 Variables](#313-variables)
  - [31.4 UI](#314-ui)
  - [31.5 Progression (lifecycle coverage)](#315-progression-lifecycle-coverage)
  - [31.6 Player Interactions](#316-player-interactions)
  - [31.7 Dependencies](#317-dependencies)
  - [31.8 AnalyticsService Usage (canon §C20)](#318-analyticsservice-usage-canon-c20)
  - [31.9 Internal Event Schema](#319-internal-event-schema)
  - [31.10 Event Catalog](#3110-event-catalog)
  - [31.11 Funnels](#3111-funnels)
  - [31.12 Economy Telemetry (reason codes)](#3112-economy-telemetry-reason-codes)
  - [31.13 KPI Definitions and Targets](#3113-kpi-definitions-and-targets)
  - [31.14 Dashboards](#3114-dashboards)
  - [31.15 Data-Driven Balancing (decision rules)](#3115-data-driven-balancing-decision-rules)
  - [31.16 Experimentation and Feature Flags](#3116-experimentation-and-feature-flags)
  - [31.17 Privacy and Compliance](#3117-privacy-and-compliance)
  - [31.18 Edge Cases](#3118-edge-cases)
  - [31.19 Acceptance Criteria](#3119-acceptance-criteria)
- [32. Tutorial](#32-tutorial)
  - [32.1 Purpose](#321-purpose)
  - [32.2 Rules & Mechanics (global)](#322-rules--mechanics-global)
  - [32.3 Variables [TUNABLE]](#323-variables-tunable)
  - [32.4 Minute-by-Minute Timeline](#324-minute-by-minute-timeline)
  - [32.5 Reward Ledger](#325-reward-ledger)
  - [32.6 Step Scripts](#326-step-scripts)
  - [32.7 UI](#327-ui)
  - [32.8 Player Interactions (multiplayer)](#328-player-interactions-multiplayer)
  - [32.9 Accessibility](#329-accessibility)
  - [32.10 Skip Rules](#3210-skip-rules)
  - [32.11 Dependencies](#3211-dependencies)
  - [32.12 Progression after the Tutorial: Contextual Tips](#3212-progression-after-the-tutorial-contextual-tips)
  - [32.13 Roblox Implementation](#3213-roblox-implementation)
  - [32.14 Edge Cases and Resume](#3214-edge-cases-and-resume)
  - [32.15 Acceptance Criteria](#3215-acceptance-criteria)
- [33. Content Expansion](#33-content-expansion)
  - [33.1 Purpose and Expansion Laws](#331-purpose-and-expansion-laws)
  - [33.2 Expansion Mini-Designs](#332-expansion-mini-designs)
  - [33.3 Identifier Plan for New Content](#333-identifier-plan-for-new-content)
  - [33.4 12-Month Roadmap](#334-12-month-roadmap)
  - [33.5 Live-Ops Cadence](#335-live-ops-cadence)
  - [33.6 Data-Driven Content Pipeline](#336-data-driven-content-pipeline)
  - [33.7 Acceptance Criteria](#337-acceptance-criteria)
- [34. Development Roadmap](#34-development-roadmap)
  - [34.1 Planning Assumptions](#341-planning-assumptions)
  - [34.2 Phase Overview and Milestone Calendar](#342-phase-overview-and-milestone-calendar)
  - [34.3 System Dependency Graph](#343-system-dependency-graph)
  - [34.4 Minimum Viable Playable Game (MVP)](#344-minimum-viable-playable-game-mvp)
  - [34.5 Phase 1 — Core Prototype (W1–W12)](#345-phase-1--core-prototype-w1w12)
  - [34.6 Phase 2 — Vertical Slice (W13–W25)](#346-phase-2--vertical-slice-w13w25)
  - [34.7 Phase 3 — Alpha (W26–W41)](#347-phase-3--alpha-w26w41)
  - [34.8 Phase 4 — Beta (W42–W55)](#348-phase-4--beta-w42w55)
  - [34.9 Phase 5 — Launch (W56–W61)](#349-phase-5--launch-w56w61)
  - [34.10 Phase 6 — Live Operations (W62 onward)](#3410-phase-6--live-operations-w62-onward)
  - [34.11 Technical Tasks by Service and Asset Production Plan](#3411-technical-tasks-by-service-and-asset-production-plan)
  - [34.12 Launch-Critical vs Post-Launch](#3412-launch-critical-vs-post-launch)
  - [34.13 Pre-Agreed Scope Cut List](#3413-pre-agreed-scope-cut-list)
  - [34.14 Risks and Mitigations](#3414-risks-and-mitigations)
- [35. Testing and QA](#35-testing-and-qa)
  - [35.1 Principles](#351-principles)
  - [35.2 Test Strategy](#352-test-strategy)
  - [35.3 Environments, Tooling and Test Data](#353-environments-tooling-and-test-data)
  - [35.4 Test-Case Conventions](#354-test-case-conventions)
  - [35.5 Area Test Plans](#355-area-test-plans)
  - [35.6 Canon Edge-Case Rulings (§C22) as Acceptance Tests](#356-canon-edge-case-rulings-c22-as-acceptance-tests)
  - [35.7 Additional Edge Cases (QA-originated)](#357-additional-edge-cases-qa-originated)
  - [35.8 Playtest and Kids' Readability Protocol](#358-playtest-and-kids-readability-protocol)
  - [35.9 Regression Suite](#359-regression-suite)
  - [35.10 Performance Test Matrix](#3510-performance-test-matrix)
  - [35.11 Exploit Testing](#3511-exploit-testing)
  - [35.12 Acceptance Gates per Phase](#3512-acceptance-gates-per-phase)
  - [35.13 Bug Severity Definitions and Triage](#3513-bug-severity-definitions-and-triage)
  - [35.14 Acceptance Criteria](#3514-acceptance-criteria)
- [36. Content Database Appendices](#36-content-database-appendices)
  - [36.1 Database Index and Identifier Conventions](#361-database-index-and-identifier-conventions)
  - [36.2 Recipe Quick Reference](#362-recipe-quick-reference)
  - [36.3 Mutation Parts Database](#363-mutation-parts-database)
  - [36.4 Mutation Synergies Database](#364-mutation-synergies-database)
  - [36.5 Morph Combination Examples](#365-morph-combination-examples)
  - [36.6 Ability Database](#366-ability-database)
  - [36.7 Status Effects Database](#367-status-effects-database)
  - [36.8 Employee Archetypes Database](#368-employee-archetypes-database)
  - [36.9 Offline Incidents Database](#369-offline-incidents-database)
  - [36.10 City Buildings Database](#3610-city-buildings-database)
  - [36.11 City Events Database](#3611-city-events-database)
  - [36.12 Restaurant Tiers and Upgrades Database](#3612-restaurant-tiers-and-upgrades-database)
  - [36.13 Furniture and Equipment Catalog](#3613-furniture-and-equipment-catalog)
  - [36.14 Animation Library](#3614-animation-library)
  - [36.15 Sound Library](#3615-sound-library)
  - [36.16 Achievements Database](#3616-achievements-database)
  - [36.17 Progression Milestones Database](#3617-progression-milestones-database)
- [37. Implementation Checklists](#37-implementation-checklists)
  - [37.1 How to Use](#371-how-to-use)
  - [37.2 Service Implementation Checklists](#372-service-implementation-checklists)
  - [37.3 Content Production Checklists](#373-content-production-checklists)
  - [37.4 Launch Checklist (Roblox Experience Settings and Operations)](#374-launch-checklist-roblox-experience-settings-and-operations)
  - [37.5 Live-Release Checklist (every Phase 6 release)](#375-live-release-checklist-every-phase-6-release)
  - [37.6 Phase Gate Checklists](#376-phase-gate-checklists)
  - [37.7 Acceptance Criteria](#377-acceptance-criteria)
- [38. Open Design Decisions](#38-open-design-decisions)
  - [38.1 Decision Process](#381-decision-process)
  - [38.2 Decision Register](#382-decision-register)
  - [38.3 Evidence Needed and Work Blocked](#383-evidence-needed-and-work-blocked)
  - [38.4 Decision Log Template](#384-decision-log-template)
  - [38.5 Acceptance Criteria](#385-acceptance-criteria)
- [39. Balancing Assumptions](#39-balancing-assumptions)
  - [39.1 How to Read the Tables](#391-how-to-read-the-tables)
  - [39.2 Global Constants (§C3, §C16.1)](#392-global-constants-c3-c161)
  - [39.3 Currencies and Economy (§C4.2–§C4.9)](#393-currencies-and-economy-c42c49)
  - [39.4 Player Statistics and XP (§C5, §C5.1, §C18)](#394-player-statistics-and-xp-c5-c51-c18)
  - [39.5 Restaurant Tiers (§C6)](#395-restaurant-tiers-c6)
  - [39.6 Cooking Timing and Quality (§C7.1, §C8)](#396-cooking-timing-and-quality-c71-c8)
  - [39.7 Patience, Satisfaction, Payment, Reputation and Anger (§C11)](#397-patience-satisfaction-payment-reputation-and-anger-c11)
  - [39.8 Combat (§C12.1)](#398-combat-c121)
  - [39.9 Mutation Budgets (§C13.3–§C13.4, §C13.7)](#399-mutation-budgets-c133c134-c137)
  - [39.10 Employees (§C4.8, §C14)](#3910-employees-c48-c14)
  - [39.11 Offline Simulation (§C15)](#3911-offline-simulation-c15)
  - [39.12 Tuning Process](#3912-tuning-process)
  - [39.13 Acceptance Criteria](#3913-acceptance-criteria)
- [40. Definition of Done](#40-definition-of-done)
  - [40.1 Levels at a Glance](#401-levels-at-a-glance)
  - [40.2 Feature Definition of Done](#402-feature-definition-of-done)
  - [40.3 Content-Item Definition of Done](#403-content-item-definition-of-done)
  - [40.4 GDD-Section Definition of Done](#404-gdd-section-definition-of-done)
  - [40.5 Release Definition of Done](#405-release-definition-of-done)
  - [40.6 Acceptance-Criteria Linkage by Section](#406-acceptance-criteria-linkage-by-section)
  - [40.7 Cross-Cutting Gates](#407-cross-cutting-gates)
  - [40.8 Launch-Readiness Checklist (Go / No-Go)](#408-launch-readiness-checklist-go--no-go)
  - [40.9 Acceptance Criteria](#409-acceptance-criteria)
- [Appendix A. Design Canon — Identifiers, Constants and Formulas](#appendix-a-design-canon--identifiers-constants-and-formulas)
  - [C0. Authoring Rules (Style & Format Contract)](#c0-authoring-rules-style--format-contract)
  - [C1. Document Structure](#c1-document-structure)
  - [C2. Identifier Conventions](#c2-identifier-conventions)
  - [C3. Global Constants](#c3-global-constants)
  - [C4. Currencies & Economy Anchors](#c4-currencies--economy-anchors)
  - [C5. Player Statistics (9) & Formulas [TUNABLE]](#c5-player-statistics-9--formulas-tunable)
  - [C6. Restaurant Tiers (fixed values) [TUNABLE]](#c6-restaurant-tiers-fixed-values-tunable)
  - [C7. Kitchen Stations (fixed list; §5 specifies every field)](#c7-kitchen-stations-fixed-list-5-specifies-every-field)
  - [C8. Preparation Actions, Ingredient States, Quality](#c8-preparation-actions-ingredient-states-quality)
  - [C9. Ingredient Tags & Guaranteed Core Ingredients](#c9-ingredient-tags--guaranteed-core-ingredients)
  - [C10. Recipe Master List (150 — names, IDs, categories, unlock levels are fixed)](#c10-recipe-master-list-150--names-ids-categories-unlock-levels-are-fixed)
  - [C11. Customers: Personalities, Satisfaction, Payment, Anger](#c11-customers-personalities-satisfaction-payment-anger)
  - [C12. Combat Constants, Abilities, Status Effects](#c12-combat-constants-abilities-status-effects)
  - [C13. Mutation System Constants & Master List](#c13-mutation-system-constants--master-list)
  - [C14. Employees](#c14-employees)
  - [C15. Offline Simulation — Canonical Model (§16–§17 elaborates with worked examples)](#c15-offline-simulation--canonical-model-1617-elaborates-with-worked-examples)
  - [C16. Morph City](#c16-morph-city)
  - [C17. Quests](#c17-quests)
  - [C18. Skill Trees (IDs)](#c18-skill-trees-ids)
  - [C19. Roblox Services (fixed names; §27 specifies every field)](#c19-roblox-services-fixed-names-27-specifies-every-field)
  - [C20. Analytics](#c20-analytics)
  - [C21. Animation & Sound IDs](#c21-animation--sound-ids)
  - [C22. Edge-Case Rulings (all sections must agree with these)](#c22-edge-case-rulings-all-sections-must-agree-with-these)

---
