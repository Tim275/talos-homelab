# Claude Code Guidelines

This document contains guidelines for Claude Code when working on this repository.

## Git Commit Messages

### Rules

1. **Single sentence only** - Commit messages must be concise and fit in one line
2. **No bullet points** - Lines starting with `- ` are forbidden
3. **No AI attribution** - All commits must appear as written by Tim275 only

### Format

```
<type>: <single sentence description>
```

### Good Examples

```bash
✅ feat: enable Kyverno with disallow-latest-tag policy
✅ fix: resolve Velero backup storage configuration
✅ chore: update ArgoCD to version 2.12.0
✅ docs: add Istio service mesh architecture
```

### Bad Examples

```bash
❌ feat: enable Kyverno
   - Enable governance-app.yaml
   - Configure policy deployment
   - Add infrastructure exemptions

❌ fix: update multiple components
   - Fix Velero config
   - Update ArgoCD settings
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `chore`: Maintenance tasks
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `perf`: Performance improvements

### Enforcement

The repository has a `commit-msg` git hook that enforces these rules:
- Located at `.git/hooks/commit-msg`
- Automatically rejects commits with bullet points
- Automatically rejects commits with AI attribution

### Why Single Sentence?

- **Clarity**: Forces concise, clear description of changes
- **History**: Makes `git log --oneline` more useful
- **Standards**: Consistent with conventional commits
- **Review**: Easier to scan and understand changes quickly

## Working with Claude Code

When Claude Code suggests commit messages, they will automatically follow these guidelines. If a commit is rejected, Claude will reformat the message to comply with the rules.
