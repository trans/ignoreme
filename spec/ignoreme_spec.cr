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
end
