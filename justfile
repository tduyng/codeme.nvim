changelog := "CHANGELOG.md"
version_file := "VERSION"

# Display all commands
default:
    @just --list

# Run luacheck linter
lint:
    @echo "Running luacheck..."
    @luacheck lua/ plugin/ --globals vim

# Format with stylua
fmt:
    @echo "Formatting with stylua..."
    @stylua lua/ plugin/

# Check formatting without changes
fmt-check:
    @echo "Checking format..."
    @stylua --check lua/ plugin/

# Run all checks (lint + format check)
check: lint fmt-check
    @echo "✓ All checks passed"

# Generate changelog for latest release
changelog:
    @echo "→ Generating changelog with git‑cliff…"
    @git cliff --latest --prepend {{ changelog }}
    @git cliff --latest --strip all --output LATEST_CHANGELOG.md
    @echo "Changelog written to {{ changelog }}"

# Create a release tag
tag VERSION:
    @echo "Creating tag v{{ VERSION }}..."
    @git checkout main
    @git pull origin main
    @echo "Updating {{ version_file }}..."
    @echo "{{ VERSION }}" > {{ version_file }}
    @echo "→ Generating changelog for v{{ VERSION }}…"
    @git cliff --unreleased --tag "v{{ VERSION }}" --prepend {{ changelog }}
    @git cliff --unreleased --tag "v{{ VERSION }}" --strip all --output LATEST_CHANGELOG.md
    @git add {{ changelog }} LATEST_CHANGELOG.md {{ version_file }}
    @git commit -m "chore(release): v{{ VERSION }}"
    @git tag -a v{{ VERSION }} -m "Release v{{ VERSION }}"
    @echo "Tag v{{ VERSION }} created. Push with: git push && git push origin v{{ VERSION }}"

# Show current version
version:
    @cat {{ version_file }}
