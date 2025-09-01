# Wiki Management Guide

This guide explains how to modify, create, and upload wiki documentation for the OnTime Flutter project.

## 📖 Overview

Our project wiki is integrated directly into the main repository using Git subtrees. This means:

- Wiki content is stored in the `docs/` folder
- Changes are version-controlled with the main codebase
- Documentation stays in sync with code changes
- New developers can access docs offline

## 🚀 Quick Start

### Prerequisites

- Git configured with your GitHub account
- Access to the OnTime-front repository
- Basic knowledge of Markdown

### Current Wiki Structure

```
docs/
├── Architecture.md      # Project structure and architecture
├── Git.md              # Git workflow and commit guidelines
├── Home.md             # Wiki homepage
└── Wiki-Management.md  # This guide
```

## ✏️ Modifying Existing Wiki Pages

### 1. Edit Files Locally

Navigate to the `docs/` folder and edit any `.md` file:

```bash
# Navigate to docs folder
cd docs/

# Edit existing files with your preferred editor
code Architecture.md
# or
vim Home.md
# or
nano Git.md
```

### 2. Preview Your Changes

Use any Markdown preview tool or your IDE's built-in preview to review changes before committing.

### 3. Commit Changes to Main Repository

```bash
# From project root
git add docs/
git commit -m "docs: update [filename] with [brief description]"
```

## 📝 Creating New Wiki Pages

### 1. Create New Markdown File

```bash
# From project root
touch docs/New-Page-Name.md
```

### 2. Add Content

Use standard Markdown syntax. Here's a template:

````markdown
# Page Title

Brief description of what this page covers.

## Section 1

Content here...

### Subsection

More detailed content...

## Code Examples

\```dart
// Flutter/Dart code examples
void main() {
print('Hello OnTime!');
}
\```

## Links and References

- [Internal Link](./Other-Page.md)
- [External Link](https://flutter.dev)
````

### 3. Update Navigation

If creating a major new page, consider updating `Home.md` to include a link to your new page.

## 🔄 Syncing with GitHub Wiki

Our project uses Git subtree to keep the main repository and GitHub wiki synchronized.

### Push Local Changes to GitHub Wiki

After committing your documentation changes to the main repository:

```bash
# Push documentation changes to GitHub wiki
git subtree push --prefix=docs wiki master
```

**What this does:**

- Takes all changes from the `docs/` folder
- Pushes them to the GitHub wiki repository
- Updates the online wiki at `https://github.com/DevKor-github/OnTime-front/wiki`

### Pull Changes from GitHub Wiki

If someone edits the wiki directly on GitHub:

```bash
# Pull changes from GitHub wiki to local docs folder
git subtree pull --prefix=docs wiki master --squash
```

**When to use this:**

- Someone edited wiki pages directly on GitHub
- You want to sync external wiki changes to your local repository
- Before starting major documentation work (to avoid conflicts)

## 🔧 Advanced Workflows

### Working on Documentation-Heavy Features

1. **Create a documentation branch:**

   ```bash
   git checkout -b docs/feature-name
   ```

2. **Make your documentation changes**

3. **Commit and push to main repository:**

   ```bash
   git add docs/
   git commit -m "docs: add documentation for feature-name"
   git push origin docs/feature-name
   ```

4. **Create PR for review**

5. **After PR merge, sync to wiki:**
   ```bash
   git checkout main
   git pull origin main
   git subtree push --prefix=docs wiki master
   ```

### Handling Merge Conflicts

If you encounter conflicts when pulling from the wiki:

1. **Resolve conflicts in the docs/ folder**
2. **Commit the resolution:**
   ```bash
   git add docs/
   git commit -m "docs: resolve wiki merge conflicts"
   ```
3. **Push resolved changes:**
   ```bash
   git subtree push --prefix=docs wiki master
   ```

## 📋 Documentation Best Practices

### File Naming Convention

- Use kebab-case: `Getting-Started.md`, `API-Guide.md`
- Be descriptive but concise
- Avoid spaces and special characters

### Content Guidelines

1. **Start with a clear title and overview**
2. **Use consistent heading hierarchy (H1 → H2 → H3)**
3. **Include code examples where relevant**
4. **Add links to related documentation**
5. **Keep content up-to-date with code changes**

### Markdown Tips

- Use `backticks` for inline code
- Use triple backticks with language for code blocks
- Use `**bold**` for emphasis
- Use `> blockquotes` for important notes
- Create tables for structured data

## 🛠️ Troubleshooting

### Common Issues

**Issue: `fatal: working tree has modifications`**

```bash
# Solution: Commit or stash changes first
git add .
git commit -m "docs: work in progress"
# or
git stash
```

**Issue: Wiki changes not appearing on GitHub**

```bash
# Solution: Ensure you pushed to the wiki remote
git subtree push --prefix=docs wiki master
```

**Issue: Local docs out of sync**

```bash
# Solution: Pull latest changes from wiki
git subtree pull --prefix=docs wiki master --squash
```

### Getting Help

- Check Git status: `git status`
- View recent commits: `git log --oneline -10`
- Check remotes: `git remote -v`
- Ask team members or create an issue

## 🎯 Recommended Documentation

For new developers, consider creating these essential pages:

- [ ] **Getting-Started.md** - Setup and installation guide
- [ ] **Development-Guide.md** - Development workflow and tools
- [ ] **API-Documentation.md** - Backend API reference
- [ ] **Testing-Guide.md** - How to run and write tests
- [ ] **Deployment.md** - Build and deployment procedures
- [ ] **Contributing.md** - Contribution guidelines
- [ ] **Troubleshooting.md** - Common issues and solutions
