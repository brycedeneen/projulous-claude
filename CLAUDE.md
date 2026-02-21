# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**IMPORTANT: Always start Claude Code from the `/projulous` root folder.** If you launched Claude from a subfolder (e.g., `projulous-svc`, `projulous-web`, or `projulous-shared-dto-node`), exit and restart from the `/projulous` directory. The multi-root workspace context, shared instructions, and agent configurations require the root as the working directory.

## Repository Structure

This is a VS Code multi-root workspace containing four projects:

- **projulous-svc**: NestJS backend API service (GraphQL + REST)
- **projulous-web**: React Router v7 frontend with Tailwind CSS
- **projulous-mobile**: Expo SDK 54 / React Native mobile app (iOS + Android)
- **projulous-shared-dto-node**: Shared TypeScript DTOs, entities, and enums used by all projects

## Common Commands

### Backend (projulous-svc)
```bash
cd projulous-svc
npm run start:dev      # Development with watch mode (RUN_LEVEL=LOCAL, uses local.dev.env)
npm run start:debug    # Debug mode with inspector (RUN_LEVEL=DEBUG, uses prod.dev.env)
npm run build          # Build for production
npm run lint           # Run ESLint with auto-fix
npm run test           # Run Jest unit tests
npm run test:watch     # Run tests in watch mode
npm run test:e2e       # Run end-to-end tests
```

### Frontend (projulous-web)
```bash
cd projulous-web
npm run dev            # Start development server
npm run build          # Build for production
npm run typecheck      # Run TypeScript type checking
npm run format         # Format with Prettier
npx playwright test    # Run Playwright e2e tests
```

### Mobile (projulous-mobile)
```bash
cd projulous-mobile
npx expo start         # Start Expo dev server
npx expo start --ios   # Start with iOS Simulator
npx expo start --android # Start with Android Emulator
npm run lint           # Run ESLint
```

### Shared DTOs (projulous-shared-dto-node)
```bash
cd projulous-shared-dto-node
npm run buildProd      # Build TypeScript to dist/
npm run lint:ts        # Run ESLint
```

## Architecture

### Backend (projulous-svc)

- **Framework**: NestJS with Apollo GraphQL and TypeORM
- **Database**: PostgreSQL with read/write replica pattern
  - Use `@InjectRepository(Entity)` for write operations
  - Use `@InjectRepository(Entity, 'read')` for read operations
- **Key Modules**: AuthModule, CustomerModule, ServiceProviderModule, ProjulousAIModule
- **Environment**: `local.dev.env` for dev mode (local DB), `prod.dev.env` for debug mode (prod DB)

### Frontend (projulous-web)

- **Framework**: React Router v7 (file-based routing in `app/routes/`)
- **Styling**: Tailwind CSS v4
- **Icons**: Lucide React, Heroicons
- **i18n**: react-i18next with translations in `app/translations/`

### Mobile (projulous-mobile)

- **Framework**: Expo SDK 54 with React Native 0.81
- **Routing**: Expo Router 6 (file-based routing)
- **Styling**: NativeWind v5 (Tailwind for React Native)
- **Path alias**: `@/` maps to project root (NOT `~/`)
- **Auth**: JWT in expo-secure-store, AuthContext + UserTypeContext

### Shared Library

Both projects depend on `projulous-shared-dto-node` via GitHub:
```
"projulous-shared-dto-node": "github:redbricksoftware/projulous-shared-dto-node"
```

**CRITICAL: NEVER use `file:` protocol** (e.g. `"file:../projulous-shared-dto-node"`) for this dependency. The `file:` protocol creates symlinks that cause duplicate module instances of `@nestjs/graphql`, `typeorm`, etc., breaking GraphQL decorator metadata on the backend and Vite ESM resolution on the frontend. Always use the GitHub reference: `"github:redbricksoftware/projulous-shared-dto-node"`.

Import pattern: `import { Entity } from 'projulous-shared-dto-node/dist/module'`

## Service Development Conventions

When creating or updating a NestJS service:

1. First run `npm install projulous-shared-dto-node` to update the shared library
2. Name the file `{singular}.service.ts`
3. Create a test spec file for the service
4. Implement standard CRUD methods:
   - `get{Plural}(user: UserAuthModel)`
   - `get{Singular}(user: UserAuthModel, {singularId}: string)`
   - `create{Singular}(user: UserAuthModel, dto: Create{Singular}Dto)`
   - `update{Singular}(user: UserAuthModel, {singularId}: string, dto: Update{Singular}Dto)`
   - `delete{Singular}(user: UserAuthModel, {singularId}: string)`
5. Use `StringUtil` to validate required/optional fields in create/update methods
6. Use the read repository for all GET operations
7. Emit events via `ProjulousEventEmitterV2` for create/update/delete operations
8. Register entities in both `app.module.ts` and the feature module

## Entity/DTO Development Conventions

When creating entities in projulous-shared-dto-node:

- **Enums**: Use format `export enum <EnumName>ENUM { KEY = 'KEY' }` with uppercase keys, place in `shared/enums/` and export from index.ts
- **Entities**: Reference `customer/project.entity.ts` as the template
- **GraphQL enums**: Add `registerEnumType(<EnumName>ENUM, { name: '<EnumName>ENUM' })` at top of entity file
- **Entity naming**: Table name pluralized, class name singular
- **DTOs**: Annotate with `@ApiProperty()` or `@ApiPropertyOptional()` for nullable fields
- **Relations**: Wrap with `Relation<>` type

## Documentation Lookup

Always use the **Context7 MCP** (`mcp__context7__resolve-library-id` and `mcp__context7__query-docs`) when you need library/API documentation, code generation examples, or setup/configuration steps. Do not rely on training knowledge for library-specific details — fetch up-to-date docs via Context7 first. This applies automatically; the user does not need to ask for it.

## Available Skills

Skills are reusable, invocable instructions in `/.claude/skills/`. Use `/skill-name` to invoke:

| Skill | Trigger | Description |
|-------|---------|-------------|
| `/add-offering-type` | User-invoked | Add offering type across full stack |
| `/web-pages` | User-invoked | Create new pages/routes in projulous-web |
| `/crud-api` | User-invoked | Create CRUD APIs in projulous-svc |
| `/shared-dto-entities` | User-invoked | Create entities/DTOs/enums in shared-dto |
| `/audit-permissions` | User-invoked | Audit permission drift between TS enums and DB |
| `/seed-permissions-and-roles` | User-invoked | Seed missing permissions/roles in DB |

## Agent Self-Improvement

Agents, skills, and this CLAUDE.md file are all editable. When confirmed patterns emerge or corrections are needed, agents should update their own definition files, relevant skills, and MEMORY.md. Always verify changes against the actual codebase before updating.

## Plans & TODO Files

All planning documents, feature plans, and TODO files should be stored in:
```
projulous/todo_and_plans/
```

When agents generate plans or roadmaps, write them to this directory rather than within individual project folders.
