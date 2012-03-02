# encoding: utf-8

require 'systemu'

module Nanoc::Filters

  # @since 3.2.0
  class AsciiDoc < Nanoc::Filter

    # Runs the content through [AsciiDoc](http://www.methods.co.nz/asciidoc/).
    # This method takes no options.
    #
    # @param [String] content The content to filter
    #
    # @return [String] The filtered content
    def run(content, params={})
      match = content.match(/\A= *([^=\n ].*)$/)
      if match
        header = "<h1>#{match[1]}</h1>\n"
      end
      # Run command
      stdout = ''
      stderr = ''
      status = systemu(
        [ 'asciidoc', '-s', '-b', 'html5mod', '-o', '-', '-' ],
        'stdin'  => content,
        'stdout' => stdout,
        'stderr' => stderr)

      # Show errors
      unless status.success?
        $stderr.puts content
        $stderr.puts stderr
        raise RuntimeError, "AsciiDoc filter failed with status #{status}"
      end

      begin
      # Get result
        stdout.force_encoding 'UTF-8'
        stdout.gsub!("\r\n","\n")
        stdout
      rescue StandardError => e
        $stderr.puts content
        $stderr.puts stdout
        raise e
      end
    end
  end

end
