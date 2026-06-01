# ufsc-tcc-thesis

Repository for the development of my final course project — formal verification of MCP security properties using the Tamarin Prover.

## Requirements

- [Tamarin Prover](https://tamarin-prover.com/) ≥ 1.8

## Project Structure

```
src/
  experiments/               # Entry points
    typosquatting_phase{1,2}_{attentive,busy,careless}.spthy
    prompt_injection_phase{1,2}_{attentive,busy,careless}.spthy
    unified_phase{1,2}_{attentive,busy,careless}.spthy
  core/                      # Shared MCP lifecycle
    base.spthy                 # Host intent, discovery request, tool execution
    discovery.spthy            # Phase 1 discovery → PendingValidation
  masks/                     # Pirandellian user profiles (shared across attacks)
    attentive.spthy
    busy.spthy
    careless.spthy
  attacks/                   # Attack-specific rules
    common.spthy
    typosquatting.spthy
    prompt_injection.spthy
  mitigations/               # Phase 2 defenses
    registry_verification.spthy   # Typosquatting: server allowlist
    contextual_friction.spthy       # Prompt injection: friction layer
  lemmas/                    # Shared security and reachability lemmas
    reachability_base.spthy
    reachability_ts.spthy
    reachability_pi.spthy
    security_ts.spthy
    security_pi.spthy
outputs/
  txt/                       # Console logs from batch runs
  proofs/                    # Annotated .spthy files with proofs
run_experiments.sh           # Batch runner script
```

---

## Model Overview

The model formalizes the **Model Context Protocol (MCP)** lifecycle under a Dolev-Yao adversary, with human decision-making abstracted as **Pirandellian masks**. Each mask encodes a different level of user attention when validating server discovery results or LLM-proposed actions.

All masks compare against the host's original intent, stored as `!HostToolIntent($H, $IntendedServerName, toolName)`.

### Phases

| Phase | Fact consumed | Attack modeled |
|---|---|---|
| **Discovery** | `PendingValidation` | Typosquatting (connecting to the wrong server) |
| **Execution** | `PendingUserDecision` | Prompt injection (executing an LLM-proposed action derived from poisoned tool output) |

In **Phase 1** experiments, no mitigations are active. In **Phase 2**, typosquatting experiments add registry verification and prompt injection experiments add contextual friction.

### Mask Validations

Mask rules live in `src/masks/`. The unified experiments (`unified_phase*`) use the same mask profile for both discovery and execution. Attack-specific experiments isolate one vector at a time.

#### Attentive

Strictest profile. Validates server identity during discovery and rejects all LLM-proposed actions during execution.

**Discovery** — checks both server name and tool name:

| Outcome | Condition |
|---|---|
| Accept | `ServerName == IntendedServerName` **and** tool name matches intent |
| Reject | `ServerName != IntendedServerName` |
| Reject | `toolName != intendedTool` (adversary advertises the wrong tool) |

**Execution** — rejects every proposed action:

| Outcome | Condition |
|---|---|
| Reject (always) | Any `PendingUserDecision` — no accept rule exists |

`PendingUserDecision` is only produced when the LLM extracts an embedded instruction from tool output. Under the data-provenance framing, a fully attentive user treats all such proposals as untrusted.

#### Busy

Partial validation: checks tool context only, ignoring server identity and action content.

**Discovery:**

| Outcome | Condition |
|---|---|
| Accept | Tool name matches `!HostToolIntent` (server name **not** checked) |
| Reject | `toolName != intendedTool` |

**Execution:**

| Outcome | Condition |
|---|---|
| Accept | Tool name matches intent (ignores server name **and** action content) |
| Reject | `toolName != intendedTool` |

Vulnerable to typosquatting when the malicious server advertises the same tool name as the legitimate one.

#### Careless

No validation at either phase.

**Discovery:**

| Outcome | Condition |
|---|---|
| Accept (always) | Any `PendingValidation`, no checks |

**Execution:**

| Outcome | Condition |
|---|---|
| Accept (always) | Any `PendingUserDecision`, no checks on action, server, or tool |

### Summary Matrix

| Mask | Discovery checks | Execution checks |
|---|---|---|
| **Attentive** | Server name + tool name | Rejects all proposed actions |
| **Busy** | Tool name only | Tool name only (ignores action content) |
| **Careless** | None | None |

### Experiment Types

| Prefix | Scope |
|---|---|
| `typosquatting_phase*` | Discovery-phase attack only (`PendingValidation`) |
| `prompt_injection_phase*` | Execution-phase attack only (`PendingUserDecision`) |
| `unified_phase*` | Both attacks in a single theory |

---

## Running Experiments

### 1. Interactive Mode (GUI)

Opens the Tamarin web interface for a specific experiment. Useful for inspecting proof trees and attack traces step by step.

```bash
tamarin-prover interactive src/experiments/
```

Then open your browser at `http://localhost:3001`. Select the desired theory from the list to load it and prove lemmas interactively.

To open a specific file directly:

```bash
tamarin-prover interactive src/experiments/unified_phase1_attentive.spthy
```

---

### 2. Isolated Mode (Single Experiment)

Proves all lemmas in a single experiment file non-interactively and prints the results to the terminal.

```bash
tamarin-prover src/experiments/<file>.spthy --prove
```

**Examples:**

```bash
# Typosquatting Phase 1 — expect no_malicious_server_accepted to be FALSIFIED (Careless, Busy)
tamarin-prover src/experiments/typosquatting_phase1_careless.spthy --prove

# Typosquatting Phase 2 — expect security lemmas to be VERIFIED
tamarin-prover src/experiments/typosquatting_phase2_attentive.spthy --prove

# Prompt Injection Phase 1 — expect no_injected_action_executed to be FALSIFIED (Careless, Busy)
tamarin-prover src/experiments/prompt_injection_phase1_busy.spthy --prove

# Prompt Injection Phase 2 — expect security lemmas to be VERIFIED
tamarin-prover src/experiments/prompt_injection_phase2_attentive.spthy --prove

# Unified model — both attacks in one theory
tamarin-prover src/experiments/unified_phase1_attentive.spthy --prove
```

To also save the output:

```bash
tamarin-prover src/experiments/typosquatting_phase1_attentive.spthy --prove \
  --output=outputs/proofs/experiments_typosquatting_phase1_attentive_proof.spthy \
  > outputs/txt/experiments_typosquatting_phase1_attentive.txt 2>&1
```

---

### 3. Batch Mode (All Experiments)

Runs all experiments in `src/experiments/` sequentially, saving logs to `outputs/txt/` and annotated proof files to `outputs/proofs/`.

```bash
chmod +x run_experiments.sh
./run_experiments.sh
```

Results are saved as:
- `outputs/txt/<name>.txt` — full Tamarin console output
- `outputs/proofs/<name>_proof.spthy` — annotated theory with proof annotations

---

## Expected Results Summary

### Typosquatting (`security_ts.spthy`)

| Phase | Mask | `no_malicious_server_accepted` | `attentive_prevents_malicious_server` |
|---|---|---|---|
| 1 | Attentive | **verified** | **verified** (non-vacuous) |
| 1 | Busy | **falsified** | **verified** (vacuous — sanity lemma falsified) |
| 1 | Careless | **falsified** | **verified** (vacuous — sanity lemma falsified) |
| 2 | All | **verified** | **verified** |

### Prompt Injection (`security_pi.spthy`)

| Phase | Mask | `no_injected_action_executed` | `friction_prevents_injection_executed` |
|---|---|---|---|
| 1 | Attentive | **verified** (vacuous — no accept rule) | N/A |
| 1 | Busy | **falsified** | N/A |
| 1 | Careless | **falsified** | N/A |
| 2 | All | **verified** | **verified** |

Vacuous results occur when the antecedent of a conditional lemma is unreachable in that experiment. Check the corresponding sanity lemmas in `security_ts.spthy` and `security_pi.spthy` to distinguish meaningful verification from vacuous truth.
