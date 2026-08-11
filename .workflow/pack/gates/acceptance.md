# Completion evidence contract

Use this contract before marking implementation tasks complete or reporting verification success.

## Required outcome

- Evidence is relevant to the changed behavior and proportional to its risk.
- Record the check and its result.
- Prefer existing automated checks when they cover the behavior.
- When no suitable automated check exists, record another concrete check or state the unverified residual.
- A failed relevant check keeps the affected work incomplete unless the user explicitly accepts the residual risk.

This contract does not prescribe a coding, testing, debugging, or reasoning method. Project rules, tool protocols, and active change artifacts may impose narrower constraints.
