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

# Create new version tag (format: vX.Y.Z)
tag VERSION:
    @echo "Creating tag v{{ VERSION }}..."
    @git checkout main
    @git pull origin main
    @echo "Updating {{ version_file }}..."
    @echo "{{ VERSION }}" > {{ version_file }}
    @echo "→ Generating changelog..."
    @git cliff --unreleased --tag "v{{ VERSION }}" --prepend {{ changelog }}
    @git cliff --unreleased --tag "v{{ VERSION }}" --strip all > RELEASE_NOTES.md
    @git add {{ changelog }} {{ version_file }}
    @git commit -m "chore: release v{{ VERSION }}"
    @git tag -a v{{ VERSION }} -m "Release v{{ VERSION }}"
    @echo "Push: git push && git push origin v{{ VERSION }}"
