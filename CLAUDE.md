# HAfAH

Read-only HAF app implementing account history API. Pure SQL (PostgreSQL + PostgREST).

## Tech Stack
- PostgreSQL 14+, PL/pgSQL, PostgREST
- Testing: Tavern, pytest, JMeter
- CI/CD: GitLab CI, Docker

## Documentation Routing

| Task | Read |
|------|------|
| Architecture/general | `scripts/claude/main.md` |
| JSON-RPC API | `scripts/claude/jsonrpc.md` |
| REST API | `scripts/claude/rest.md` |
| Utilities | `scripts/claude/utilities.md` |
| Tests | `scripts/claude/tests.md` |
| Debugging/CI | `scripts/claude/tools.md` |

## Database Schemas
- `hafah_backend` - Implementation functions and utilities
- `hafah_endpoints` - PostgREST-exposed API functions

## Key Directories
- `backend/` - SQL implementation (utilities, jsonrpc, rest)
- `endpoints/` - PostgREST-exposed wrappers
- `db/` - Schema creation and roles

## External Dependencies
**HAF**: Read-only access to HAF base tables. No replay needed.

## Specialized Agents
- **hafah-dev**: For hafah development tasks
- **hafah-reviewer**: For code review and quality verification
- **gitlab-pipeline-engineer**: For commits, MRs, pipeline issues

## Expansion Rules
When modifying this project:
- JSON-RPC functions → `scripts/claude/jsonrpc.md`
- REST functions → `scripts/claude/rest.md`
- Utilities → `scripts/claude/utilities.md`
- Tests → `scripts/claude/tests.md`
