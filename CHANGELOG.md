## Changelog

All notable changes to PROMTOK will be documented in this file.

The project follows semantic versioning when possible. Dates are in YYYY-MM-DD.

### [0.1.4] - 2025-08-20
- New: Jina.ai integration for web search and content fetching.
- Improved: Automatic expansion of vague search queries.
- Enhanced: Better handling of JavaScript-heavy sites via Jina fetcher (can be slower).

### [0.1.3] - 2025-08-15
- Breaking: Migrated from SQLite/ChromaDB to PostgreSQL with pgvector.
- Action required: Use `docker compose down -v` before upgrading; fresh volumes required.
- New requirements: PostgreSQL with pgvector (included in Docker setup).
- Security: All credentials configurable via environment variables.

### [Unreleased]
- Planned: Additional robustness for outline generation with smaller-context local LLMs.
- Planned: Documentation refinements and more examples for CLI ingestion.

