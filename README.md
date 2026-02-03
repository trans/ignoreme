# ignore

A .gitignore compatible pattern parser for Crystal.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     ignore:
       github: trans/ignore
   ```

2. Run `shards install`

## Usage

```crystal
require "ignore"

# Parse gitignore content
matcher = Ignore.parse(<<-GITIGNORE
  build/
  *.o
  *.log
  !important.log
GITIGNORE
)

matcher.ignores?("build/")       # => true (directory)
matcher.ignores?("main.o")       # => true
matcher.ignores?("debug.log")    # => true
matcher.ignores?("important.log") # => false (negated)

# Quick one-liner
Ignore.ignores?("foo.log", "*.log")  # => true
```

### Directory Matching

Use a trailing slash to check directories:

```crystal
matcher = Ignore.parse("build/")
matcher.ignores?("build/")  # => true (directory)
matcher.ignores?("build")   # => false (file)
```

### Building Patterns Incrementally

```crystal
matcher = Ignore::Matcher.new
matcher.add("*.o")
matcher.add("*.log")
matcher.add("!important.log")
matcher.ignores?("test.o")  # => true

# Inspect and manage patterns
matcher.patterns  # => ["*.o", "*.log", "!important.log"]
matcher.size      # => 3
matcher.clear     # remove all patterns

# Enumerable support
matcher.each { |pattern| puts pattern }
matcher.select { |p| p.starts_with?("*") }
```

### Loading from a Directory Tree

Load all `.gitignore` files from a project, with patterns scoped to their directories:

```crystal
matcher = Ignore.root("/path/to/project")
matcher.ignores?("src/debug.log")
```

This loads `.gitignore` files from the root and all subdirectories. Patterns from deeper directories take precedence, so a `!debug.log` in `src/.gitignore` will override `*.log` in the root `.gitignore`.

You can also load other ignore file formats:

```crystal
# Load .dockerignore files
matcher = Ignore.root("/path/to/project", ".dockerignore")

# Load .npmignore files
matcher = Ignore.root("/path/to/project", ".npmignore")
```

### Loading Individual Files

```crystal
matcher = Ignore::Matcher.new
matcher.add_file(".gitignore")
matcher.add_file("src/.gitignore", base: "src/")
```

### Managing Ignore Files

Use `Ignore::File` to read, modify, and save ignore files:

```crystal
file = Ignore::File.new(".gitignore")

# Inspect patterns
file.patterns   # => ["*.log", "build/"]
file.lines      # => ["# Build artifacts", "*.log", "", "build/"]
file.size       # => 2 (pattern count, excludes comments/blanks)

# Modify patterns
file.add("*.tmp")
file.remove("*.log")
file.includes?("*.tmp")  # => true

# Check paths against patterns
file.ignores?("debug.tmp")  # => true

# Save changes (preserves comments and blank lines)
file.save

# Reload from disk (discards unsaved changes)
file.reload

# Enumerable support (iterates over patterns only)
file.each { |pattern| puts pattern }
```

### Filtered Directory Operations

Use `Ignore::Dir` for filtered directory listings and glob results:

```crystal
dir = Ignore::Dir.new("/path/to/project", "*.log", "build/")

dir.glob("**/*.cr")           # filtered glob
dir.children                   # filtered directory children
dir.entries                    # filtered entries (includes . and ..)
dir.each_child { |entry| ... } # filtered iteration

# Include hidden files in glob
dir.glob("**/*", match: :dot_files)

# Load patterns from .gitignore files automatically
dir = Ignore::Dir.new("/path/to/project", root: ".gitignore")

# Load from a single ignore file
dir = Ignore::Dir.new("/path/to/project", file: ".gitignore")
```

Directory patterns like `build/` will filter out the directory and all its contents.

#### Inverse Filtering

Get only the ignored files (useful for cleanup tools):

```crystal
dir = Ignore::Dir.new("/path/to/project", "*.log", "build/")

dir.ignored_glob("**/*")       # only ignored paths
dir.ignored_children           # only ignored children
dir.ignored_entries            # only ignored entries
dir.each_ignored_child { |e| } # iterate ignored children
```

#### Enumerable Support

`Ignore::Dir` includes `Enumerable`, iterating over non-ignored children:

```crystal
dir = Ignore::Dir.new("/path/to/project", "*.log")
dir.select { |entry| entry.ends_with?(".cr") }
dir.map { |entry| entry.upcase }
```

#### Dir Monkey Patch (Optional)

For convenience, you can optionally load a monkey patch that adds `ignore` methods to `Dir`:

```crystal
require "ignore/core_ext"

# Class method (uses current directory)
Dir.ignore("*.log", "build/").glob("**/*")
Dir.ignore(root: ".gitignore").glob("**/*")

# Instance method
Dir.new("/path/to/project").ignore("*.log").glob("**/*")
Dir.new("/path/to/project").ignore(root: ".gitignore").children
```

## Supported Patterns

| Pattern | Description |
|---------|-------------|
| `*.txt` | Wildcard, matches any `.txt` file |
| `?` | Single character wildcard |
| `[abc]` | Character class |
| `[a-z]` | Character range |
| `[!abc]` | Negated character class |
| `build/` | Directory only (trailing slash) |
| `/root` | Anchored to root (leading slash) |
| `foo/bar` | Anchored (contains slash) |
| `!pattern` | Negation (un-ignore) |
| `**/foo` | Match in all directories |
| `foo/**` | Match everything inside |
| `a/**/b` | Zero or more directories between |
| `\#` `\!` | Escaped special characters |

## License

MIT
