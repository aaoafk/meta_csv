# frozen_string_literal: true

require "csv"
require_relative "os"
require "parallel"

module MetaCsv
  # TODO: This is not a `Parser` by definition of what a `Parser` does...
  class Parser # :nodoc:
    BLOCK_SIZE = 4096

    attr_accessor :inferred_encoding, :csv_chunks

    def initialize(file:)
      @csv_chunks = []
      initialize_chunks file
    end

    private

    # TODO: Figure out how to stream over the network.
    CsvChunk = csv_chunk_data_structure

    # def initialize_chunks stream
    #   # TODO: Implement
    # end

    def initialize_chunks file
      raise "#{file} does not exist...Is this the correct file path?" unless File.exist? file

      # Determine encoding
      @inferred_encoding = infer_encoding_or_default file

      File.open(file) do |f|
        headers = f.first
        f.foreach(BLOCK_SIZE) do |lines|
          csv_chunks << CsvChunk.new(
            rows: CSV.parse(lines.join, encoding: inferred_encoding, headers: headers, header_converters: converters, skip_blanks: true)
          )
        end
      end

      # HACK: Benchmark with threads vs. ractors and compare to `async`...
      ::Parallel.map(csv_chunks, in_ractors: OS.cores, ractor: [Parser, :process_chunks], progress: true)
    end

    def self.process_chunks chunk
      # Remove duplicate rows from further processing

      chunk.rows.to_a.shuffle!
      chunk.rows.to_a.uniq!
      # resolve duplicate headers by grabbing the first value or everything
      chunk.rows.each do |row|
        seen = {}
        row.each_pair do |header, val|
          seen[header] ||= []
          seen[header] << val
        end
        vals = seen.transform_values { |v| (v.size == 1) ? v[0] : v }
        vals.each { |k, v| row[k] = v }
      end
    end

    private_class_method :process_chunks

    def infer_encoding_or_default file
      if OS.linux? || OS.unix?
        return `file --mime #{file}`.strip.split("charset=").last
      elsif OS.mac?
        return `file -I #{file}`.strip.split("charset=").last
      end

      # Default
      Encoding.default_external.to_s
    end

    def converters
      funcs = []

      underscore = ->(word) {
        x = /(?=a)b/
        r = /(?:(?<=([A-Za-z\d]))|\b)(#{x})(?=\b|[^a-z])/
        word.gsub!(r) { "#{$1 && "_"}#{$2.downcase}" }
        word.gsub!(/([A-Z])(?=[A-Z][a-z])|([a-z\d])(?=[A-Z])/) { ($1 || $2) << "_" }
        word.tr!("-", "_")
        word.tr! " ", "_"
        word.downcase!
        word
      }

      funcs << proc { |field| underscore.call field }
      funcs << proc { |field| field.to_sym }
    end

    def csv_chunk_data_structure
      if RUBY_VERSION > 3.2
        Data.define :rows
      else
        Struct.new :rows
      end
    end

    class ParserError < StandardError; end

    class InvalidSourceCSVError < ParserError; end

    class SchemaValidationFailedError < ParserError; end

    class NoHeadersProvidedError < ParserError; end
  end
end
