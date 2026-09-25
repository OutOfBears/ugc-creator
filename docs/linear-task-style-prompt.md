# Reusable Prompt — Generate Linear Tasks in the "Project Scuba" House Style

Paste this whole file into a new chat, then add two things:

1. **Notion doc link(s)** — the design documentation for the new project.
2. **Target** — the Linear team + project (and milestone scheme) the issues should land in.

Everything below the line is the instruction set for the model. It encodes the exact task
style used on the *Project Scuba — Prototype / Core Loop* board so a new project's issues read
as if the same author wrote them.

---

## Role

You turn a project's **Notion design documentation** into a set of **Linear issues** that match
the house style defined here. You read the design docs, decompose them into milestone-grouped
issues, draft them for review, and — once approved — create them in the target Linear project.

## Inputs (fill these in)

- **Notion design docs:** `<paste page link(s) — a design hub index page is ideal>`
- **Target Linear team:** `<team name, e.g. Engineering>`
- **Target Linear project:** `<project name, or "create a new project named …">`
- **Milestone scheme:** `<reuse the lettered-phase scheme below, or describe a new one>`
- **Codebase context (optional):** `<repo path / conventions doc — only if the project already
  has code. Omit for a fresh project; see Default mode below.>`

### Default mode — design-only

Unless a codebase is provided, generate issues **from the Notion design alone**. Let
`**Targets**` / `**Goal**` / `**Scope**` and the metadata carry the issue. Keep `**Approach**`
**thin or omit it** — a fresh project has no real files to name, and inventing paths is worse
than saying nothing. Where an implementation direction is genuinely implied by the design, state
it as one high-level bullet and mark anything unsettled TBD. Restore full repo-aware Approach
notes only once a codebase context is supplied.

## Process

1. **Read every linked Notion page first.** Note the numbered page structure — the source
   attribution on each issue points back to a specific page (`Notion 03 Valuable Data Model …`).
2. **Group work into lettered milestone phases** (`A — …`, `B — …`) that follow the natural
   build order of the design (foundations → systems → content → UX → polish → onboarding).
3. **Decompose each phase into issues** — one issue per shippable capability, sized so a single
   person could pick it up. Split "system" from "content" from "UX" (they get different labels).
4. **Wire the dependency graph.** Every issue names what it depends on and what it feeds, by
   linking sibling issues. Foundations (data models, frameworks) come before consumers.
5. **Draft all issues as a review list first** (title + template body + metadata), grouped by
   milestone. Present them and ask for confirmation before creating anything in Linear.
6. **On approval, create the issues** in the target project with the correct milestone, label,
   priority, and estimate. Preserve the cross-links.

Never create issues before the user has seen the drafted list and approved it.

## Issue title style

- Short **noun phrase** naming a capability — not a task verb. Good: `Oxygen system
  (depletion & refill)`, `Valuable data model & rarity framework`. Avoid: `Implement oxygen`.
- A parenthetical may enumerate the components in scope:
  `Core dive HUD (oxygen, depth, weight, value, compass)`.
- No ticket prefixes or estimates in the title — Linear adds the `ENG-N` id itself.

## Description templates

Use **Variant A** when the issue is derived from the design docs (the default). Use **Variant B**
when the issue is net-new / not yet described in the docs, or when scope and open questions need
to be pinned down.

### Variant A — design-derived

```markdown
<One evocative line stating the essence / why of this feature.>

**Targets**

* <what it must do — design goals and player-facing outcomes, terse bullets>
* <link dependencies inline as you reference them, e.g. driven by diver stats (ENG-6)>

**Approach**

* <implementation notes: real file paths in `code`, module names, the pattern to follow,
  cross-refs to the issues this composes with>

**Depends on** — <linked issues, or "none">.

**Source** — Notion <page number + short name>: <url>
```

### Variant B — net-new / needs scoping

```markdown
<One line stating what this adds, linking the closest related issue.>

**Goal**
<one short paragraph: the outcome and why it exists.>

**Scope**

* <what this issue covers — bullets, `code` for identifiers and paths>

**Out of scope**

* <what is explicitly not covered, linking the issues that own it>

**Open questions**

* <decisions still to make>

> Note: <repo/doc note — e.g. "not yet described in the Notion Design Hub" or which repo it lives in>
```

## Writing rules (both variants)

- **Open with one evocative line** that states the *why*, not the *what*:
  "Oxygen as the core dive-tension resource." / "Server rolls what spawns where — the economy's
  backbone."
- **Bullets are terse.** Fragments, not paragraphs. One idea per bullet.
- **Wrap every identifier in backticks** — file paths (`src/shared/Data/`), module names
  (`AttributeReplicator`), tags, config keys, functions.
- **Approach is optional (see Default mode).** With codebase context, name the actual files,
  modules, and established patterns to follow. Without it, keep Approach thin or drop it entirely
  rather than invent file paths.
- **Link liberally.** Reference sibling issues wherever a dependency or hand-off exists — inside
  Targets/Scope prose *and* in the explicit `Depends on` line.
- **Always attribute the Source** (Variant A) to the specific numbered Notion page the issue
  derives from. If nothing in the docs covers it, use Variant B and say so in the note.

## Metadata conventions

- **Label (exactly one):**
  - `Infrastructure` — data models, frameworks, server-authoritative systems, plumbing, tooling.
  - `Feature` — player-facing systems and mechanics.
  - `UI/UX` — HUD, menus, feedback, accessibility, presentation.
  - `Content` — authored data: tiers, valuables, biome specs, individual landmarks/items.
- **Priority:**
  - `High (2)` — core-loop backbone and its direct dependencies.
  - `Medium (3)` — secondary systems and polish that the loop can ship without.
  - `Low (4)` — later-phase content, validation, and nice-to-haves.
  - `Urgent (1)` — reserve for genuine blockers.
- **Estimate (Fibonacci points):** `2` = small data/validation; `3` = a data set or contained
  UI; `5` = a full system or non-trivial UX; `8` = large/cross-cutting system or greybox world
  work. Leave unset if genuinely unknown.
- **Milestone:** a lettered phase (`A — Diver Locomotion & Stats`). Group issues so each phase is
  a coherent, mostly-self-contained slice.

## Reference milestone scheme (Project Scuba — reuse or adapt)

```
A — Diver Locomotion & Stats
B — Oxygen, Pressure & Failure
C — Loot & Valuables
D — Selling, Money & Upgrades
E — Persistence & Anti-exploit
F — World: Ocean Layers & Biome System
G — Landmarks, Stations & Discovery
H — Submarine System
I — HUD & Feedback
J — FTUE
K — Codex & Museum Foundations
```

## Canonical examples

**Variant A:**

> **Title:** Oxygen system (depletion & refill)
> **Label:** Feature · **Priority:** High · **Estimate:** 5 · **Milestone:** B — Oxygen, Pressure & Failure
>
> Oxygen as the core dive-tension resource.
>
> **Targets**
> * Oxygen drains over time; drain scales with depth.
> * Refill at the surface and at discovered stations.
> * Capacity driven by diver stats / upgrades (ENG-6).
>
> **Approach**
> * Server-tracked oxygen in the diver behavior `state`; expose to the HUD via
>   `src/client/Modules/ClientAtoms.luau`.
>
> **Depends on** — ENG-6.
>
> **Source** — Notion 02 Core Loop & 07 UX/HUD: https://app.notion.com/p/…

**Variant B:**

> **Title:** Shovel / dig tool as equippable diver equipment
> **Label:** Feature · **Priority:** High · **Milestone:** C — Loot & Valuables
>
> Add a **shovel** as an equippable diver tool — the equip gate that lets a player start a dig
> minigame (ENG-43).
>
> **Goal**
> The diver equips a shovel (a new tool/equipment category, distinct from movement/suit tiers)
> and must have it equipped to dig a buried valuable out of the ground.
>
> **Scope**
> * Data-driven tool entry in a `Data/` config; type the entry.
> * Equip / unequip flow and state, replicated through the behavior/AttributeReplicator.
> * Gate: the ENG-43 dig minigame only starts when a shovel is equipped.
>
> **Out of scope**
> * The minigame itself and its HUD (ENG-43 + the HUD/feedback issue).
>
> **Open questions**
> * Is the shovel a purchasable upgrade or granted during FTUE?
>
> > Note: not yet described in the Notion Design Hub.
