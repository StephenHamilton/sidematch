#!/usr/bin/env ruby

require 'optparse'
require 'set'

class ParallelComparator
  def initialize(args,output=$stdout)
    @output = output
    if output.tty?
      @color = true
    end
    ordered_args = parse_options(args)
  end

  def parse_options(args)
    @ifs = $/
    @ofs = $/
    @tab = " "
    @print_matches = true
    @print_failures = true
    @silent = false
    @quiet = false
    @line_numbers = false
    # parse options out of ARGV
    OptionParser.new do |opts|
      opts.banner += " source_file [target_file]"
      opts.version = "0.5"

      opts.on("-m", "--matches", "Only print matches") do
        unless @print_matches
          $stderr.puts "Invalid options, -m and -M are mutually exclusive"
          exit 5
        end
        
        @print_failures = false
      end

      opts.on("-M", "--no-matches", "Only print failures") do
        unless @print_failures
          $stderr.puts "Invalid options, -m and -M are mutually exclusive"
          exit 5
        end
        
        @print_matches = false
      end

      opts.on("-q", "--quiet", "Do not print details to stderr") do
        @quiet = true
      end

      opts.on("-s", "--silent", "Do not print anything at all.") do
        @quiet = true
        @silent = true
      end

      opts.on("-0", "Use null as the input and output delimeter.", "  This will be superceeded by -d or -D") do
        @ifs = "\0"
        @ofs = "\0"
      end

      opts.on("-d delimeter", "Input delimeter. By default this is a newline.") do |separator|
        @ifs[:separator] = separator
      end

      opts.on("-D delimeter", "Output delimeter. By default this is a newline.") do |separator|
        @ofs = separator
      end

      opts.on("-l", "--line-numbers", "Print line numbers at the start of each line.") do
        @line_numbers = true
      end

      opts.on("-T column_delimeter", "Specify the characters to separate the columns with.", "  The default is a single space.") do |tab|
          @tab = tab
      end

      opts.on("-t", "Delimit columns with a tab. Equivalent to \"-T \\t\".") do |tab|
          @tab = "\t"
      end

      opts.on("-c", "Force color output") do 
        @color = true
      end

      opts.on("-C", "Disable color output.") do 
        @color = false
      end

      begin 
        opts.order!(args)
        return args
      rescue OptionParser::ParseError => error
        $stderr.puts error
        $stderr.puts "-h or --help will show valid options"
        exit 5
      end

    end

  end

  def open(source, target=nil)
    unless source.is_a? String
      source_file = source
    else
      unless File.file? source
        $stderr.puts "The file \"" +  source + "\" was not found."
        exit 6
      end

      source_file = File.open(source)
    end

    if target.nil? || target == "-"
      target_file = $stdin
    elsif !target.is_a? String
      target_file = target
    else
      unless File.file? target
        $stderr.puts "The file \"" + target + "\" was not found."
        exit 6
      end

      @check_file = File.open(target)
    end

    return [source_file,target_file]
  end

  def compare(source, target=nil)
    source_file, target_file = open(source, target)
    
    line_number = 0
    failures = 0
    too_short = false
    too_long = false

    while line = source_file.gets(@ifs)
      failed = false
      output = ""
      line_number += 1
      if @line_numbers
        output += line_number.to_s + @tab
      end
      line_strip = line[0..(-(@ifs.length+1))]
      output += line_strip + @tab
      input_line = target_file.gets(@ifs)
      if ! input_line.nil?
        input_line_strip = input_line[0..(-(@ifs.length+1))]
        if line_strip == input_line_strip
          if @color
            output += "\033[0;32m"
          else
            output = "+" + @tab + output
          end
        else
          if @color
            output += "\033[1;31m"
          else
            output = "-" + @tab + output
          end
          failed = true
          failures += 1
        end
        output += input_line_strip
      else 
        if @print_failures
          if @color
            output += "\033[0;35m"
          else
            output = "-" + @tab + output
          end
          output += "EOF"
          if @color
            output += "\033[0m"
          end
          unless @silent
            @output.printf "%s%s", output, @ofs
          end
        end
        too_short = true
        break
      end

      if (failed && @print_failures) || (!failed && @print_matches)
        unless @silent
          if @color
            output += "\033[0m"
          end
          @output.printf "%s%s", output, @ofs
        end
      end
    end

    if too_short
      remaining = source_file.readlines(@ifs).count
      unless @quiet
        $stderr.puts "The test input was #{remaining + 1} line#{remaining > 0 ? "s" : ""} too short."
      end
    else
      remaining = target_file.readlines(@ifs).count
      if remaining > 0
        too_long = true
        unless @quiet
          $stderr.puts "The test input was #{remaining} line#{remaining > 1 ? "s" : ""} longer than expected."
        end
      end
    end

    if failures > 0 || too_short
      return 1
    elsif too_long
      #TODO add flag to ignore this
      return 2
    else
      return 0
    end

    if target_file != $stdin
      target_file.close
    end
    source_file.close
  end

end

if __FILE__ == $0
  comparator = ParallelComparator.new(ARGV)
  exit comparator.compare(*ARGV)
end
