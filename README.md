# Alpine Apex

Godot downhill racing with a custom ski solver. Start with [AGENTS.md](AGENTS.md)
for project rules and task-specific documentation.

- Run: `./godotw.ps1`; editor: `./godotw.ps1 --editor`.
- New checkout, native toolchain and exports: [Development](docs/DEVELOPMENT.md).
- Runtime ownership and current identities: [Architecture](docs/ARCHITECTURE.md).
- Checks and open acceptance: [Validation](docs/VALIDATION.md).
- Agreed future work: [backlog](backlog/README.md).

`scripts/` owns game code and tooling; `scenes/` and `main.tscn` compose it.
`assets/` contains runtime assets, `art_source/` editable sources and references,
`native/` engine/DSP integration, `tests/` fixtures and suites. Generated output
belongs in ignored `artifacts/` or `builds/`; local toolchains live in `.tools/`.
