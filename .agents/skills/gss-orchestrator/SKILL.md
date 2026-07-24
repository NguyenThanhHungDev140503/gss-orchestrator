```markdown
# gss-orchestrator Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches the core development patterns and conventions used in the `gss-orchestrator` TypeScript codebase. It covers file naming, import/export styles, commit message conventions, and testing patterns. The repository does not use a framework and follows a clean, modular TypeScript structure with conventional commit messages and a focus on maintainability.

## Coding Conventions

### File Naming
- All files use **kebab-case**.
- Example:  
  ```
  my-module.ts
  user-service.test.ts
  ```

### Import Style
- **Relative imports** are used throughout the codebase.
- Example:
  ```typescript
  import { doSomething } from './utils/do-something';
  ```

### Export Style
- **Named exports** are preferred.
- Example:
  ```typescript
  // In utils/do-something.ts
  export function doSomething() { ... }
  ```

### Commit Messages
- **Conventional commit** format is used.
- Common prefix: `refactor`
- Example:
  ```
  refactor: extract helper function for request validation
  ```

## Workflows

### Refactoring Code
**Trigger:** When improving code structure or readability without changing functionality  
**Command:** `/refactor`

1. Identify code that can be improved (e.g., extract functions, rename variables).
2. Make changes, following the file naming and import/export conventions.
3. Commit with a message like:
   ```
   refactor: improve error handling in orchestrator
   ```
4. Push your changes and open a pull request if required.

## Testing Patterns

- Test files use the `*.test.ts` naming pattern.
- The testing framework is **unknown** (not detected), but tests are written in TypeScript.
- Example test file:
  ```
  orchestrator.test.ts
  ```
- Place test files alongside the code they test or in a dedicated `tests` directory.

## Commands
| Command     | Purpose                                             |
|-------------|-----------------------------------------------------|
| /refactor   | Start a code refactor following repository patterns |

```