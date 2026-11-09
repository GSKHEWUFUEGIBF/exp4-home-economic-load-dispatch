# Home Energy Economic Load Dispatch: Hopfield Network vs Lambda Iteration

This project compares two economic load-dispatch solvers in a 24-hour Simulink model of a home energy system. The available sources are solar PV, a battery, the utility grid, and a diesel generator. The model records hourly dispatch, cost, marginal cost, solver iterations, and power-balance mismatch.

## Method

- A demand profile, PV availability profile, and time-dependent battery limit drive the 24 hourly dispatch steps.
- Lambda iteration provides the conventional economic-dispatch baseline.
- A Hopfield neural network computes an independent dispatch solution for comparison.
- Offline replicas of both methods cross-check the Simulink outputs; the script also exports convergence and dispatch figures.

## Recorded results

| Measure | Lambda iteration | Hopfield network |
| --- | ---: | ---: |
| Daily cost (Rs) | 195.143 | 194.818 |
| Maximum power mismatch (W) | 0.000 | 6.376 |
| Mean iterations per hour | 6.417 | 14,089.375 |

For this run, the Hopfield solver reported a slightly lower raw daily cost, with a small residual power-balance mismatch and substantially more iterations. The lambda solver met the reported balance tolerance with fewer iterations. Cost comparisons should therefore be read together with the mismatch and convergence figures.

## Requirements and run

Requires MATLAB R2018b or later and Simulink.

From the repository root, run:

```matlab
build_Exp4_Simulink
```

The script builds and simulates `Exp4_Simulink/Exp4_Home_ELD_Hopfield_vs_Lambda.slx` and writes figures to `Exp4_Simulink/figures/`.

## Repository contents

- `build_Exp4_Simulink.m` — builds the model, simulates both solvers, cross-checks results, and exports figures.
- `Exp4_Simulink/Exp4_Home_ELD_Hopfield_vs_Lambda.slx` — 24-step home energy dispatch model.
- `Exp4_Simulink/figures/` — load/PV profile, solver convergence, dispatch, costs, mismatch, and model diagrams.

## Scope

The results describe the included simulation scenario and parameter set; they are not a field deployment or hardware benchmark. No software license is specified in this repository.
