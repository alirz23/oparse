require "optparse"

module Oparse

    VERSION = "0.1.0"

    class Parser

        attr_accessor :banner, :version

        def initialize(settings = {})
            @options = []
            @used_short = []
            @default_values = {}
            @settings = settings
            yield self if block_given?
        end

        def option(name, desc, settings = {})
            settings = @settings.clone.merge(settings)
            @options << {name: name, description: desc, settings: settings}
        end

        def short_form(name)
            name.to_s.chars.each do |c|
                next if @used_short.include?(c) || c == "_"
                return c # return from short method
            end
            return name.to_s.chars.first
        end

        def validate(result)
            result.each_pair do |key, value|
                o = @options.find_all { |option| option[:name] == key }.first
                key = "--" << key.to_s.gsub("_", "-")
                unless o[:settings][:value_in_set].nil? || o[:settings][:value_in_set].include?(value)
                    puts "Parameter for #{key} must be in [" << o[:settings][:value_in_set].join(", ") << "]"
                    exit(1)
                end
                unless o[:settings][:value_in_set].nil? || o[:settings][:value_in_set] =~ value
                    puts "Parameter for #{key} must match /" << o[:settings][:value_in_set].source << "/"
                    exit(1)
                end
                unless o[:settings][:value_in_set].nil? || o[:settings][:value_in_set].call(value)
                    puts "Parameter for #{key} must satisfy given conditions (see description)"
                    exit(1)
                end
            end
        end

        def process!(arguments = ARGV)
            @result = @default_values.clone
            @parser ||= OptionParser.new do |p|
                @options.each do |o|
                    @used_short << short = o[:settings][:no_short] ? nil : o[:settings][:short] || short_form(o[:name])
                    @result[o[:name]] = o[:settings][:default] || false unless o[:settings][:optional]
                    name = o[:name].to_s.gsub("_", "-")
                    klass = o[:settings][:default].class == Fixnum ? Integer : o[:settings][:default].class

                    args = [o[:description]]
                    args << "-" + short if short
                    if [TrueClass, FalseClass, NilClass].include?(klass)
                        args << "--[no-]"+name
                    else
                        args << "--" + name + " " + o[:settings][:default].to_s << klass
                    end

                    p.on(*args) { |x| @result[o[:name]] = x }
                end

                p.banner = @banner unless @banner.nil?
                p.on_tail("-h", "--help", "show this message") { puts p; exit }
                short = @used_short.include?("v") ? "-V" : "-v"
                p.on_tail(short, "--version", "print version") { puts @version; exit } unless @version.nil?
            end
            @default_values = @result.clone

            begin
                @parser.parse!(arguments)
            rescue OptionParser::ParseError => e
                puts e.message; exit(1)
            end

            validate(@result) if self.respond_to?("validate")
            @result
        end

    end # parser

end
