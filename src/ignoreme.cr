require "./ignoreme/pattern"

module Ignoreme
  VERSION = "0.1.0"

  # A collection of gitignore patterns that can match paths
  class Matcher
    @patterns : Array(Pattern)

    def initialize
      @patterns = [] of Pattern
    end

    # Add a single pattern string
    def add(pattern : String) : self
      stripped = pattern.strip
      return self if stripped.empty? || stripped.starts_with?("#")
      @patterns << Pattern.new(stripped)
      self
    end

    # Parse gitignore content (multiple lines)
    def parse(content : String) : self
      content.each_line do |line|
        add(line)
      end
      self
    end

    # Check if a path should be ignored
    # Use trailing / for directories: ignores?("build/")
    def ignores?(path : String) : Bool
      result = false

      @patterns.each do |pattern|
        if pattern.matches?(path)
          result = !pattern.negated?
        end
      end

      result
    end

    # Returns the number of patterns
    def size : Int32
      @patterns.size
    end

    # Check if matcher has any patterns
    def empty? : Bool
      @patterns.empty?
    end
  end

  # Parse gitignore content and return a Matcher
  def self.parse(content : String) : Matcher
    Matcher.new.parse(content)
  end

  # Quick check if a path matches patterns
  def self.ignores?(path : String, patterns : String) : Bool
    parse(patterns).ignores?(path)
  end
end
