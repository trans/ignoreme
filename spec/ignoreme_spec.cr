require "./spec_helper"

describe Ignoreme do
  describe "VERSION" do
    it "has a version" do
      Ignoreme::VERSION.should_not be_nil
    end
  end

  describe Ignoreme::Pattern do
    describe "basic patterns" do
      it "matches simple filename" do
        pattern = Ignoreme::Pattern.new("foo.txt")
        pattern.matches?("foo.txt").should be_true
        pattern.matches?("bar.txt").should be_false
      end

      it "matches at any depth when no slash" do
        pattern = Ignoreme::Pattern.new("foo.txt")
        pattern.matches?("foo.txt").should be_true
        pattern.matches?("a/foo.txt").should be_true
        pattern.matches?("a/b/foo.txt").should be_true
      end

      it "matches with * wildcard" do
        pattern = Ignoreme::Pattern.new("*.txt")
        pattern.matches?("foo.txt").should be_true
        pattern.matches?("bar.txt").should be_true
        pattern.matches?("foo.log").should be_false
      end

      it "* does not match across directories" do
        pattern = Ignoreme::Pattern.new("*.txt")
        pattern.matches?("a/b.txt").should be_true  # matches b.txt at any level
        pattern = Ignoreme::Pattern.new("a*.txt")
        pattern.matches?("a/b.txt").should be_false # a*.txt doesn't match a/b.txt
      end

      it "matches with ? wildcard" do
        pattern = Ignoreme::Pattern.new("foo?.txt")
        pattern.matches?("foo1.txt").should be_true
        pattern.matches?("fooa.txt").should be_true
        pattern.matches?("foo.txt").should be_false
        pattern.matches?("foo12.txt").should be_false
      end
    end

    describe "directory patterns" do
      it "trailing slash matches only directories" do
        pattern = Ignoreme::Pattern.new("build/")
        pattern.directory_only?.should be_true
        pattern.matches?("build/").should be_true
        pattern.matches?("build").should be_false
      end

      it "trailing slash matches directories at any depth" do
        pattern = Ignoreme::Pattern.new("build/")
        pattern.matches?("build/").should be_true
        pattern.matches?("a/build/").should be_true
        pattern.matches?("a/b/build/").should be_true
      end
    end

    describe "anchored patterns" do
      it "leading slash anchors to root" do
        pattern = Ignoreme::Pattern.new("/foo.txt")
        pattern.anchored?.should be_true
        pattern.matches?("foo.txt").should be_true
        pattern.matches?("a/foo.txt").should be_false
      end

      it "middle slash anchors pattern" do
        pattern = Ignoreme::Pattern.new("a/foo.txt")
        pattern.anchored?.should be_true
        pattern.matches?("a/foo.txt").should be_true
        pattern.matches?("b/a/foo.txt").should be_false
      end
    end

    describe "negation" do
      it "detects negation" do
        pattern = Ignoreme::Pattern.new("!important.txt")
        pattern.negated?.should be_true
        pattern.matches?("important.txt").should be_true
      end

      it "escaped ! is not negation" do
        pattern = Ignoreme::Pattern.new("\\!important.txt")
        pattern.negated?.should be_false
        pattern.matches?("!important.txt").should be_true
      end
    end

    describe "double asterisk **" do
      it "**/foo matches foo anywhere" do
        pattern = Ignoreme::Pattern.new("**/foo")
        pattern.matches?("foo").should be_true
        pattern.matches?("a/foo").should be_true
        pattern.matches?("a/b/foo").should be_true
      end

      it "foo/** matches everything inside foo" do
        pattern = Ignoreme::Pattern.new("foo/**")
        pattern.matches?("foo/a").should be_true
        pattern.matches?("foo/a/b").should be_true
        pattern.matches?("foo").should be_false
      end

      it "a/**/b matches zero or more directories between" do
        pattern = Ignoreme::Pattern.new("a/**/b")
        pattern.matches?("a/b").should be_true
        pattern.matches?("a/x/b").should be_true
        pattern.matches?("a/x/y/b").should be_true
      end
    end

    describe "character classes" do
      it "matches character class" do
        pattern = Ignoreme::Pattern.new("[abc].txt")
        pattern.matches?("a.txt").should be_true
        pattern.matches?("b.txt").should be_true
        pattern.matches?("c.txt").should be_true
        pattern.matches?("d.txt").should be_false
      end

      it "matches character range" do
        pattern = Ignoreme::Pattern.new("[a-z].txt")
        pattern.matches?("a.txt").should be_true
        pattern.matches?("m.txt").should be_true
        pattern.matches?("z.txt").should be_true
        pattern.matches?("1.txt").should be_false
      end

      it "negated character class" do
        pattern = Ignoreme::Pattern.new("[!abc].txt")
        pattern.matches?("a.txt").should be_false
        pattern.matches?("d.txt").should be_true
        pattern.matches?("1.txt").should be_true
      end
    end

    describe "escaping" do
      it "escaped # is literal" do
        pattern = Ignoreme::Pattern.new("\\#file")
        pattern.matches?("#file").should be_true
      end

      it "escaped * is literal" do
        pattern = Ignoreme::Pattern.new("foo\\*.txt")
        pattern.matches?("foo*.txt").should be_true
        pattern.matches?("foobar.txt").should be_false
      end
    end

    describe "base_path" do
      it "pattern with base_path only matches within that path" do
        pattern = Ignoreme::Pattern.new("*.log", "src/")
        pattern.base_path.should eq("src/")
        pattern.matches?("src/debug.log").should be_true
        pattern.matches?("src/sub/debug.log").should be_true
        pattern.matches?("debug.log").should be_false
        pattern.matches?("other/debug.log").should be_false
      end

      it "anchored pattern with base_path anchors to base" do
        pattern = Ignoreme::Pattern.new("/build", "src/")
        pattern.matches?("src/build").should be_true
        pattern.matches?("src/sub/build").should be_false
        pattern.matches?("build").should be_false
      end

      it "normalizes base_path with trailing slash" do
        pattern = Ignoreme::Pattern.new("*.log", "src")
        pattern.base_path.should eq("src/")
      end
    end
  end

  describe Ignoreme::Matcher do
    it "ignores comments" do
      matcher = Ignoreme::Matcher.new
      matcher.add("# this is a comment")
      matcher.size.should eq(0)
    end

    it "ignores blank lines" do
      matcher = Ignoreme::Matcher.new
      matcher.add("")
      matcher.add("   ")
      matcher.size.should eq(0)
    end

    it "applies patterns in order, last match wins" do
      matcher = Ignoreme::Matcher.new
      matcher.add("*.txt")
      matcher.add("!important.txt")
      matcher.ignores?("foo.txt").should be_true
      matcher.ignores?("important.txt").should be_false
    end

    it "parses multiline content" do
      content = <<-GITIGNORE
      # Build output
      build/
      *.o

      # Keep important files
      !important.o
      GITIGNORE

      matcher = Ignoreme.parse(content)
      matcher.ignores?("build/").should be_true
      matcher.ignores?("foo.o").should be_true
      matcher.ignores?("important.o").should be_false
    end

    describe "hierarchical patterns" do
      it "add with base restricts pattern to subtree" do
        matcher = Ignoreme::Matcher.new
        matcher.add("*.log", "src/")
        matcher.ignores?("src/debug.log").should be_true
        matcher.ignores?("debug.log").should be_false
      end

      it "parse with base restricts all patterns to subtree" do
        matcher = Ignoreme::Matcher.new
        matcher.parse("*.log\n*.tmp", "src/")
        matcher.ignores?("src/debug.log").should be_true
        matcher.ignores?("src/cache.tmp").should be_true
        matcher.ignores?("debug.log").should be_false
      end

      it "deeper patterns take precedence" do
        matcher = Ignoreme::Matcher.new
        matcher.add("*.log")           # ignore all .log files
        matcher.add("!debug.log", "src/")  # but not debug.log in src/
        matcher.ignores?("app.log").should be_true
        matcher.ignores?("src/app.log").should be_true
        matcher.ignores?("src/debug.log").should be_false
      end
    end
  end

  describe "module-level API" do
    it "Ignoreme.parse returns a Matcher" do
      matcher = Ignoreme.parse("*.txt")
      matcher.should be_a(Ignoreme::Matcher)
      matcher.ignores?("foo.txt").should be_true
    end

    it "Ignoreme.ignores? provides quick check" do
      Ignoreme.ignores?("foo.txt", "*.txt").should be_true
      Ignoreme.ignores?("foo.log", "*.txt").should be_false
    end
  end

  describe "file and directory loading" do
    it "add_file loads patterns from a file" do
      Dir.cd(Dir.tempdir) do
        File.write(".gitignore", "*.log\n*.tmp")
        matcher = Ignoreme::Matcher.new
        matcher.add_file(".gitignore")
        matcher.ignores?("debug.log").should be_true
        matcher.ignores?("cache.tmp").should be_true
        matcher.ignores?("main.cr").should be_false
        File.delete(".gitignore")
      end
    end

    it "add_file with base restricts to subtree" do
      Dir.cd(Dir.tempdir) do
        File.write("test.gitignore", "*.log")
        matcher = Ignoreme::Matcher.new
        matcher.add_file("test.gitignore", "src/")
        matcher.ignores?("src/debug.log").should be_true
        matcher.ignores?("debug.log").should be_false
        File.delete("test.gitignore")
      end
    end

    it "add_file returns self for missing files" do
      matcher = Ignoreme::Matcher.new
      matcher.add_file("/nonexistent/.gitignore")
      matcher.size.should eq(0)
    end

    it "from_directory loads all .gitignore files" do
      Dir.cd(Dir.tempdir) do
        # Create test directory structure
        Dir.mkdir_p("testproj/src/lib")

        File.write("testproj/.gitignore", "*.log")
        File.write("testproj/src/.gitignore", "*.tmp\n!important.tmp")
        File.write("testproj/src/lib/.gitignore", "!debug.log")

        matcher = Ignoreme.from_directory("testproj")

        # Root patterns apply everywhere
        matcher.ignores?("app.log").should be_true
        matcher.ignores?("src/app.log").should be_true

        # src patterns only in src/
        matcher.ignores?("src/cache.tmp").should be_true
        matcher.ignores?("cache.tmp").should be_false
        matcher.ignores?("src/important.tmp").should be_false

        # Deeper negation overrides
        matcher.ignores?("src/lib/debug.log").should be_false

        # Cleanup
        File.delete("testproj/src/lib/.gitignore")
        File.delete("testproj/src/.gitignore")
        File.delete("testproj/.gitignore")
        Dir.delete("testproj/src/lib")
        Dir.delete("testproj/src")
        Dir.delete("testproj")
      end
    end
  end
end
