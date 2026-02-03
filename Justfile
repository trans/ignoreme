# Default task
default: test

# Run tests
test:
  crystal spec

# Run tests with verbose output
test-verbose:
  crystal spec --verbose

# Generate API documentation
docs:
  crystal docs -o docs/api

# Format source code
fmt:
  crystal tool format src spec

# Check formatting without modifying
fmt-check:
  crystal tool format --check src spec

# Run linter (ameba)
lint:
  ameba

# Build and check for warnings
build:
  crystal build src/ignore.cr -o /dev/null --no-codegen

# Clean generated files
clean:
  rm -rf docs/api lib .crystal

# Install dependencies
deps:
  shards install

# Update dependencies
deps-update:
  shards update

# Run all checks (format, lint, test)
check: fmt-check test

# Release workflow: check, tag, push
release version:
  @echo "Releasing v{{version}}..."
  just check
  git tag v{{version}}
  git push origin v{{version}}
