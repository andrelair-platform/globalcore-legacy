# AGENTS.md — globalcore-legacy

Tiny repo-specific context. Org rules (`minicloud-gitops/.claude/rules/*`) still apply.

## Policy
- This is a **deliberately-legacy** insurance System of Record (Java 8 / Spring / SOAP / batch /
  shared PostgreSQL schema) built as a **practice sandbox** to wrap — NOT a real ktayl product.
  Part of the legacy-modernization initiative: `ktayl-integration/docs/legacy-wrapper-initiative-spec.md`.
- **FROZEN RULE:** never add a modern capability *inside* GlobalCore. New features are built AROUND it
  (Anti-Corruption Layer → strangler-fig). If you're tempted to edit the SOAP/schema to make a modern
  feature easier — stop; that defeats the exercise.
- **Keep it authentically legacy:** SOAP/XML only (no REST/JSON), batch (not real-time), business rules
  in DB stored procs, cryptic shared schema. Don't "modernize" these.
- Runs **outside k8s** (docker compose on the controller). Not part of the GAP wrapper-chart standard.
- **NEVER involve Retrieva.** This is the ktayl IS practice layer.

## Build / run
`docker compose up --build` (builds in JDK 8 via multi-stage; no local JDK needed). WSDL at
`/ws/policy.wsdl`. See README for SOAP examples.
