# Claude AI Usage Guidelines

## IMPORTANT: Git Commit Rules

**NEVER include Claude as Co-Author in commits!**

When using Claude Code for development assistance:

### ❌ FORBIDDEN in commits:
- `Co-Authored-By: Claude <noreply@anthropic.com>`
- `🤖 Generated with [Claude Code](https://claude.ai/code)`
- Any mention of Claude, AI, or automation in commit messages
- Any reference to Claude in commit metadata

### ✅ ALLOWED:
- Clean, professional commit messages describing the actual changes
- Focus on technical improvements and business value
- Standard commit conventions (feat:, fix:, docs:, etc.)

### Example of CORRECT commit:
```
feat: Optimize Talos cluster health checks and Gateway API bootstrap

- Enable stricter cluster validation with skip_kubernetes_checks=false
- Reduce health check timeout from 20m to 10m for faster bootstrap
- Remove manual delays from Cilium bootstrap job
- Gateway API now shows proper ACCEPTED and PROGRAMMED status
```

### Example of INCORRECT commit:
```
feat: Some changes

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Why This Matters

1. **Professional Standards**: Git history should reflect human authorship
2. **Legal Clarity**: Avoid ambiguity about code ownership
3. **Team Collaboration**: Clear attribution to actual human contributors
4. **Industry Best Practices**: AI assistance should not appear in permanent records

## Usage Guidelines

- Use Claude for development assistance and learning
- Review and understand all suggested changes before implementing
- Take full responsibility for all committed code
- Ensure all commits reflect your own technical decisions and work