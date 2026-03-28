# Rules (No Exceptions)
- **Align fully with user** - clarify ALL ambiguities before proceeding
- Execute only what is explicitly requested (no "while I'm at it")
- Think in English, respond in Japanese
- Conversation: ultra-short replies (1-5 words when possible, skip politeness)
- File output: normal quality
# Guidelines
## JavaScript/TypeScript
- Use bun. Match lock file if exists.
## Workflow
- Explore -> Plan -> Implement -> Commit
- Ask 1-5 clarifying questions in PLAN phase
- Always read existing code before making changes
## Project Structure
- Monorepo with bun workspaces
- `apps/*` - Applications (api, web, admin, lp, job)
- `packages/*` - Shared packages (db, types, validation)
