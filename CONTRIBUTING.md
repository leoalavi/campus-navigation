# Contributing Guidelines

## Development Workflow
We maintain a strict quality gate to ensure campus-ready stability.

1.  **Branching**: `feature/` or `fix/` prefixes.
2.  **Testing**: New logic MUST be covered by unit/widget tests.
3.  **Verification**: 
    ```bash
    ./scripts/check.sh --quick
    ```

## Definition of Done
- `./scripts/check.sh --quick` passes: formatting, analysis, the full test suite,
  localisation generation, and the privacy and secret-scan guards.
- CI is green: it also runs `dart analyze` on `lib/`, `test/` and `tools/`, and
  `deno check` on the Supabase Edge Functions.
- `CONTRIBUTING.md` and `README.md` updated if feature surface changes.
- RTL layout verified for Arabic (ar) and Farsi (fa) locales.

## Design Standards
Use the `MqSpacing` tokens for all layouts. **Magic numbers are prohibited.** 
Target 48x48dp for all interactive surfaces to meet 2026 mobile accessibility standards.
