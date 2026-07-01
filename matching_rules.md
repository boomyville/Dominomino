# Dominomino — Matching Rules

## Overview

Each domino occupies **2 cells** on the board. Every cell carries exactly **one pip value**. When a domino is placed adjacent to another, the pip values of touching cells are compared to determine validity, energy cost, and chain progression.

---

## Pip Values & Special Types

| Value | Meaning |
|-------|---------|
| `0–6` | Standard pip value |
| `-1` (Wild) | Always matches any pip, no energy reduction |
| `-2` (Unplayable) | Cannot match anything — blocks placement |

---

## Energy Cost

The base cost of playing a domino is the **sum of its two pip values**.

```
Base Cost = left_pip + right_pip
```

When a pip-match occurs, the **matched pip value is subtracted** from the cost (floored at 0).

```
Final Cost = max(0, Base Cost − matched_reduction)
```

**Matched reduction** = the pip value of each candidate cell that successfully matches an adjacent board cell (one reduction per candidate cell, capped once per cell).

### Cost Examples

| Domino | Situation | Base Cost | Reduction | Final Cost |
|--------|-----------|-----------|-----------|------------|
| `[3, 2]` | Played isolated (no adjacency) | 5 | 0 | **5** |
| `[3, 2]` | 3-end touches board cell with pip 3 | 5 | 3 | **2** |
| `[3, 2]` | Both ends match (3→3, 2→2) | 5 | 5 | **0** |
| `[0, 1]` | Both cells touch `[5, 2]` but 0≠5, 1≠2 | 1 | 0 | **1** |
| `[5, 2]` | 2-end touches board cell with pip 2 | 7 | 2 | **5** |

---

## Chain

- **Increment** by 1 each time a domino is placed adjacent to another (with at least one touching cell pair)
- **Reset** to 0 when a domino is placed with no adjacent neighbours, or when a placement is cancelled

---

## Match Modes

Three modes control how strictly adjacency rules are enforced.

---

### `SINGLE_MATCH` *(default)*

The strictest mode. A domino may only touch **one other domino**, and only **one cell-to-cell contact** is permitted across the entire placement.

**Rules:**
1. All touching pip pairs must match
2. The candidate may only touch **one distinct board domino** in total
3. Only **one cell-to-cell contact** is allowed (total contacts across both candidate cells must be ≤ 1)
4. Each board cell may only have **one neighbour** — if a board cell is already adjacent to a placed domino, it is "taken" and cannot be touched again

#### Legal Moves — SINGLE_MATCH

```
Board:  [2][3]      Candidate: [3][4]
```

| Placement | Touching cells | Pip match? | Legal? |
|-----------|---------------|------------|--------|
| `[3][4]` to the right of `[2][3]` | Candidate-left(3) ↔ Board-right(3) | ✓ 3=3 | **✓ Legal** |
| `[4][3]` to the right of `[2][3]` | Candidate-left(4) ↔ Board-right(3) | ✗ 4≠3 | **✗ Illegal** |
| `[3][4]` to the left of `[2][3]` | Candidate-right(4) ↔ Board-left(2) | ✗ 4≠2 | **✗ Illegal** |

#### Illegal Moves — SINGLE_MATCH

```
Board:  [2][2]
        [2][2]   ← Candidate forming a square (2 contacts to same domino)
```

| Scenario | Why illegal |
|----------|-------------|
| Candidate touches 2 cells of the same board domino (square) | `total_contacts = 2 > 1` |
| Candidate bridges two board dominoes | Touches 2 distinct board dominoes |
| Board cell already has a neighbour on that side | Cell is "taken" |

---

### `MULTI_MATCH`

Relaxed mode. A domino can touch **multiple board dominoes** and the **same pip-end can be shared** by multiple neighbours — as long as **all** touching pip pairs match.

**Rules:**
1. All touching pip pairs must match
2. No limit on how many board dominoes the candidate touches
3. No limit on how many dominoes share the same board pip-end
4. Each candidate cell still contributes at most one reduction

#### Legal Moves — MULTI_MATCH

```
Board:  [2][2]
Candidate: [2][2] placed directly below (square formation)
```

| Placement | Touching cells | Pip match? | Legal? |
|-----------|---------------|------------|--------|
| Square `[2][2]` below `[2][2]` | Left(2)↔Board-left(2), Right(2)↔Board-right(2) | ✓ 2=2, 2=2 | **✓ Legal** |
| `[3][2]` bridging `[3][?]` and `[?][2]` on board | Left(3)↔3, Right(2)↔2 | ✓ both match | **✓ Legal** |

#### Illegal Moves — MULTI_MATCH

| Scenario | Why illegal |
|----------|-------------|
| `[5][2]` with 5-end touching board pip 3 | 5≠3, pip mismatch |
| `[3][4]` bridging `[3][?]` and `[?][5]` | Right(4) ↔ board(5): 4≠5, mismatch |

#### Cost Example — MULTI_MATCH

```
Board has [3][3] placed. Candidate [3][3] placed in a square below it.
```

| Cell | Candidate pip | Board pip | Match? | Reduction |
|------|--------------|-----------|--------|-----------|
| Left cell | 3 | 3 | ✓ | +3 |
| Right cell | 3 | 3 | ✓ | +3 |

**Base cost:** 6 · **Reduction:** 6 · **Final cost: 0**

---

### `ANY_MATCH`

Free placement mode. A domino can be placed **anywhere** regardless of pip values. Energy reduction still follows the standard pip-match rule.

**Rules:**
1. No pip matching required — placement is always valid as long as cells are empty
2. No contact limits — touch as many dominoes as you like
3. Energy reduction **only applies when touching pip values happen to match**
4. Chain still increments on any adjacency (even non-matching)

#### Placement Examples — ANY_MATCH

| Placement | Touching | Pip match? | Legal? | Reduction |
|-----------|----------|------------|--------|-----------|
| `[5][2]` next to `[3][4]`, 2-end touches 4 | 2↔4 | ✗ | **✓ Legal** | 0 |
| `[5][2]` next to `[3][2]`, 2-end touches 2 | 2↔2 | ✓ | **✓ Legal** | 2 |
| `[0][1]` below `[5][2]`, 0↔5 and 1↔2 | 0≠5, 1≠2 | ✗ both | **✓ Legal** | 0 |
| `[2][2]` below `[2][2]` | 2↔2, 2↔2 | ✓ both | **✓ Legal** | 4 |

---

## Mode Comparison Table

| Rule | `SINGLE_MATCH` | `MULTI_MATCH` | `ANY_MATCH` |
|------|---------------|--------------|------------|
| Pip values must match to place | ✓ | ✓ | ✗ |
| Max board dominoes touched | 1 | Unlimited | Unlimited |
| Max cell-to-cell contacts | 1 | Unlimited | Unlimited |
| Board cell can be touched by >1 neighbour | ✗ | ✓ | ✓ |
| Energy reduction on pip match | ✓ | ✓ | ✓ |
| Energy reduction on pip mismatch | N/A (blocked) | N/A (blocked) | ✗ (no reduction) |
| Chain on adjacency | ✓ | ✓ | ✓ |
| Chain reset on isolated placement | ✓ | ✓ | ✓ |

---

## Geometry Rules (All Modes)

These rules apply regardless of match mode.

| Rule | Detail |
|------|--------|
| Each domino occupies exactly 2 cells | Horizontal: `(x,y)` and `(x+1,y)` · Vertical: `(x,y)` and `(x,y+1)` |
| Cannot overlap | Both target cells must be empty |
| Board boundary | Cannot exceed grid bounds (default 10×10) |
| Pip per cell | Each cell carries exactly one pip value based on orientation |
| Adjacency is cell-to-cell | Any of the 4 cardinal neighbours counts as a contact |

### Cell-to-Pip Mapping

| Orientation | Left/Top cell pip | Right/Bottom cell pip |
|-------------|------------------|-----------------------|
| Horizontal (rot 0) | `left_pip_value` | `right_pip_value` |
| Vertical CW (rot 1) | `left_pip_value` (top) | `right_pip_value` (bottom) |
| Horizontal flipped (rot 2) | `right_pip_value` | `left_pip_value` |
| Vertical CCW (rot 3) | `right_pip_value` (top) | `left_pip_value` (bottom) |

---

## Wild & Unplayable Pips

| Pip | Behaviour in SINGLE/MULTI_MATCH | Behaviour in ANY_MATCH |
|-----|---------------------------------|------------------------|
| `-1` Wild | Always matches any pip · No energy reduction contributed | Same |
| `-2` Unplayable | Hard blocks placement if either side is unplayable | Hard blocks placement |

---

## Preview Tile Colours

| Tile | Meaning |
|------|---------|
| `empty_board_tile.png` / `empty_board_tile2.png` | Empty cell (checkerboard) |
| `empty_board_tile3.png` | Valid placement preview (green) |
| `empty_board_tile4.png` | Geometry valid but pip/contact rules block placement (red) |