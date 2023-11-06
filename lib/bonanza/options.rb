require "optparse"

module Bonanza
  class Options

    def self.parse
      options = {}
      OptionParser.new do |parser|

        parser.on("-v", "--verbose", "Run with logging") do |args|
          options["verbose"] = true
        end

        # TODO: Handle YAML array syntax
        parser.on("-o", "--options \"key1: value1\",\"key2: [value1, value2]\"", Array, "Specify config options for this run") do |arg|
          arg.each { |a| options.merge!(YAML.load(a)) }
        end

      end.parse!

      options
    end

  end
end
