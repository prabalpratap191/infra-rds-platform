# Contributing to RDS Platform Infrastructure

Thank you for your interest in contributing! This document provides guidelines for contributing to the RDS Platform infrastructure repository.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Release Process](#release-process)

## Code of Conduct

By participating in this project, you agree to:

- Be respectful and inclusive
- Provide constructive feedback
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

1. Install required tools:
   - Terraform >= 1.5.0
   - AWS CLI >= 2.0
   - Git
   - Code editor (VS Code recommended)

2. Fork the repository
3. Clone your fork:
   ```bash
   git clone https://github.com/your-username/infra-rds-platform.git
   cd infra-rds-platform
   ```

4. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/original-org/infra-rds-platform.git
   ```

### Local Development

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes
3. Test locally in a dev environment
4. Commit your changes

## Development Workflow

### Branch Naming Convention

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions or modifications

Examples:
- `feature/add-read-replica-support`
- `fix/security-group-rule-issue`
- `docs/update-deployment-guide`

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Build process or auxiliary tool changes

Examples:
```
feat(rds): add read replica support

Implements read replica configuration for horizontal scaling.
Adds new module for replica management.

Closes #123
```

```
fix(security): correct security group ingress rules

Fixes issue where bastion host couldn't connect to RDS.
Updates security group rules to allow port 5432 from bastion SG.

Fixes #456
```

## Coding Standards

### Terraform

1. **Formatting**: Always run `terraform fmt -recursive`
2. **Validation**: Run `terraform validate` before committing
3. **Naming Conventions**:
   - Resources: `snake_case`
   - Variables: `snake_case`
   - Modules: `kebab-case`

4. **File Organization**:
   ```
   module/
   ├── main.tf        # Primary resources
   ├── variables.tf   # Input variables
   ├── outputs.tf     # Output values
   └── README.md      # Module documentation
   ```

5. **Variable Documentation**:
   ```hcl
   variable "instance_class" {
     description = "RDS instance class (e.g., db.t3.medium)"
     type        = string
     default     = "db.t3.medium"
     
     validation {
       condition     = can(regex("^db\\.", var.instance_class))
       error_message = "Instance class must start with 'db.'"
     }
   }
   ```

6. **Resource Tagging**:
   ```hcl
   tags = merge(
     var.common_tags,
     {
       Name        = "resource-name"
       Environment = var.environment
       ManagedBy   = "Terraform"
     }
   )
   ```

### Shell Scripts

1. Use `#!/bin/bash` shebang
2. Enable strict mode: `set -euo pipefail`
3. Use meaningful variable names (UPPERCASE for globals)
4. Add comments for complex logic
5. Validate inputs and handle errors

### YAML (Kubernetes)

1. Use 2 spaces for indentation
2. Add descriptive comments
3. Follow Kubernetes naming conventions
4. Include labels and annotations

## Testing

### Pre-Commit Checks

Run these before committing:

```bash
# Format Terraform code
terraform fmt -recursive

# Validate Terraform
cd terraform
terraform init -backend=false
terraform validate

# Check shell scripts
shellcheck scripts/*.sh

# Validate YAML
yamllint kubernetes/
```

### Integration Testing

1. Test in a dev environment first
2. Verify all resources are created correctly
3. Test connectivity and functionality
4. Run verification script:
   ```bash
   ./scripts/verify-deployment.sh dev
   ```

### Test Checklist

- [ ] Terraform format and validation pass
- [ ] No hardcoded values
- [ ] Variables have descriptions
- [ ] Outputs are documented
- [ ] Security groups follow least privilege
- [ ] Encryption is enabled
- [ ] Monitoring is configured
- [ ] Documentation is updated

## Documentation

### Required Documentation

When adding new features:

1. **README.md**: Update with new features
2. **Module README**: Document new modules
3. **Variables**: Add descriptions and defaults
4. **Outputs**: Document all outputs
5. **Examples**: Provide usage examples
6. **CHANGELOG.md**: Add entry under `[Unreleased]`

### Documentation Style

- Use clear, concise language
- Include code examples
- Add diagrams where helpful
- Keep it up-to-date

## Pull Request Process

### Before Submitting

1. Update your fork:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. Run all tests and checks
3. Update documentation
4. Update CHANGELOG.md

### PR Template

```markdown
## Description
[Brief description of changes]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested in dev environment
- [ ] All tests pass
- [ ] Documentation updated

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-reviewed the code
- [ ] Commented complex code
- [ ] Updated documentation
- [ ] No new warnings
- [ ] Added tests
- [ ] All tests pass

## Screenshots (if applicable)
[Add screenshots]

## Related Issues
Closes #[issue number]
```

### Review Process

1. Maintainers will review within 2 business days
2. Address review comments
3. Request re-review after changes
4. PR will be merged after approval

### Merge Criteria

- [ ] All checks pass
- [ ] At least one approval from maintainer
- [ ] No unresolved conversations
- [ ] Documentation is updated
- [ ] CHANGELOG is updated

## Release Process

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

1. Update VERSION file
2. Update CHANGELOG.md:
   - Move `[Unreleased]` to `[X.Y.Z]`
   - Add release date
3. Create release commit:
   ```bash
   git commit -m "chore: release v1.2.0"
   ```
4. Create git tag:
   ```bash
   git tag -a v1.2.0 -m "Release version 1.2.0"
   ```
5. Push changes and tag:
   ```bash
   git push origin main
   git push origin v1.2.0
   ```
6. Create GitHub release with release notes

## Questions or Need Help?

- Open an issue for bugs or feature requests
- Tag maintainers for urgent issues
- Join our Slack channel: #rds-platform
- Email: devops-team@company.com

## Recognition

Contributors will be recognized in:
- GitHub contributors page
- Release notes
- Annual contributor acknowledgment

Thank you for contributing to the RDS Platform Infrastructure!
