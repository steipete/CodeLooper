# SwiftLint Integration

This project uses [SwiftLint](https://github.com/realm/SwiftLint) to enforce consistent code style and catch potential issues in Swift code.

## How It Works

SwiftLint has been integrated in several ways:

1. **Build-time checking**: SwiftLint runs automatically during the build process
2. **Standalone linting**: A dedicated script for running SwiftLint on-demand
3. **Git pre-commit hook**: Prevents committing code with linting issues

## Running SwiftLint

### During Build

SwiftLint runs automatically as part of the normal build process. If linting issues are found, the build will continue but show warnings.

### Manually

To run SwiftLint without building the project:

```bash
# From the mac directory
./run-swiftlint.sh
```

#### Options

The `run-swiftlint.sh` script supports several options:

```bash
# Use a specific configuration file
./run-swiftlint.sh --config ./scripts/ci-swiftlint.yml

# Force exclusion (ignore "file not found" errors for excluded files)
./run-swiftlint.sh --force-exclude
```

### Using Git Pre-Commit Hook

To set up the Git pre-commit hook (which runs automatically before each commit):

```bash
# From the mac directory
./setup-git-hooks.sh
```

## Configuration

### Main Configuration

The SwiftLint rules are configured in the `.swiftlint.yml` file in the mac directory. To modify the rules:

1. Edit `.swiftlint.yml`
2. Run `./run-swiftlint.sh` to see the effects of your changes

### CI-Specific Configuration

For CI environments, we use a specialized configuration at `scripts/ci-swiftlint.yml` that:

1. Uses pattern-based exclusion instead of specific file paths
2. Handles non-existent files gracefully
3. Prevents CI failures due to excluded files not being found

Example pattern-based exclusions:

```yaml
excluded:
  - .build
  - build
  - Dependencies
  - '**/*.bak' # Exclude all .bak files using pattern
  - '**/*~' # Common temp file pattern
  - '**/.DS_Store'
```

## CI Integration and PR Comments

SwiftLint results are automatically posted as comments on GitHub pull requests. This process:

1. Runs `run-swiftlint.sh` during CI
2. Saves results to `lint-results.txt` and generates a summary in `lint-summary.md`
3. Uses the `ensure-lint-summary.sh` script to ensure the summary file exists
4. Posts the summary as a comment on the PR using GitHub Actions

If you encounter issues with PR comments, check:

- The `scripts/ensure-lint-summary.sh` script exists and is executable
- The `scripts/build.sh` script calls `ensure_lint_summary()` at the end

## Resolving SwiftLint Issues

SwiftLint provides detailed information about each issue, including:

- The file and line number of the issue
- A description of the issue
- The rule that was violated

Some issues can be automatically fixed by running:

```bash
# From the mac directory
swiftlint --fix
```

Alternatively, you can use our provided script that handles configuration automatically:

```bash
./run-swiftlint.sh --fix
```

## Disabled Rules

Some rules are intentionally disabled in our configuration:

- `trailing_whitespace`: Not critical for our codebase
- `identifier_name`: We have some short variable names that are meaningful in context
- `unused_optional_binding`: Sometimes used for pattern matching
- `cyclomatic_complexity`: Some of our legacy code is complex

## Opt-In Rules

We've enabled several opt-in rules to encourage best practices:

- `array_init`: Prefer array literal over initializers
- `contains_over_filter_count`: More efficient operations for collections
- `force_unwrapping`: Avoid force unwrapping optionals
- `sorted_imports`: Keep imports organized
- And many others for code clarity and performance

## SwiftLint Installation

SwiftLint is installed via Homebrew by the project setup script. This approach:

1. Significantly improves build times (minutes faster)
2. Avoids compiling SwiftLint during your build
3. Eliminates overhead from SwiftMacros processing

### Automatic Installation

SwiftLint is automatically installed via Homebrew during:

- `pnpm install` (via the postinstall script)
- `pnpm setup-hooks` (when setting up git hooks)

### Manual Installation

To install SwiftLint manually:

```bash
brew install swiftlint
```

### Updating SwiftLint

To update SwiftLint to the latest version:

```bash
brew upgrade swiftlint
```

## Troubleshooting CI Linting Issues

### "File not found" errors for excluded files

This happens when SwiftLint tries to exclude a file that doesn't exist (like `.bak` files). We've fixed this with:

1. Pattern-based exclusion in `scripts/ci-swiftlint.yml` (e.g., `**/*.bak` instead of specific paths)
2. The `--force-exclude` flag in CI environments
3. A CI-specific configuration that's more resilient to missing files

### Missing lint summary for PR comments

If the PR comment workflow fails with "ENOENT: no such file or directory, open 'lint-summary.md'":

1. Check that `scripts/ensure-lint-summary.sh` exists and is executable
2. Verify that `scripts/build.sh` calls the `ensure_lint_summary()` function
3. Run `chmod +x scripts/ensure-lint-summary.sh` to ensure it's executable

The `ensure-lint-summary.sh` script:

- Copies an existing lint summary from the mac directory to the repository root if available
- Creates a fallback summary file if none exists
- Is called automatically at the end of the CI build process
