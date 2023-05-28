# frozen_string_literal: true

require 'csv'
require 'active_support/core_ext/string/inflections'
require_relative 'meta_csv_base'
require_relative 'os'
require 'parallel'

module MetaCsv
  class Parser # :nodoc:
    include MetaCsvBase

    attr_accessor :csv_table, :headers, :inferred_encoding, :csv_chunks

    def initialize(file:)
      @csv_chunks = Array.new
      @csv_table = initialize_chunks file
    end

    private

    CsvChunk = Data.define(:rows)
    def initialize_chunks file
      raise "#{file} does not exist...Is this the correct file path?" unless File.exist? file

      # Determine encoding
      @inferred_encoding = infer_encoding_or_default file

      File.open(file) do |f|
        headers = f.first
        f.lazy.each_slice(BATCH_SIZE) do |lines|
          csv_chunks << CsvChunk.new(
            rows: CSV.parse(lines.join, encoding: inferred_encoding, headers: headers, header_converters: converters, skip_blanks: true)
          )
        end
      end

      ::Parallel.map(csv_chunks, in_ractors: OS.cores, ractor: [Parser, :process_chunks], progress: true)
      ::Parallel.map(csv_chunks, in_ractors: OS.cores, ractor: [Parser, :shuffle_chunk_data], progress: true)
    end

    def self.shuffle_chunk_data chunk
      chunk.rows.to_a.shuffle!
    end

    def self.process_chunks chunk
      # Remove duplicate rows from further processing
      chunk.rows.to_a.uniq!
      # resolve duplicate headers by grabbing the first value or everything
      chunk.rows.each do |row|
        seen = {}
        row.each_pair do |header, val|
          seen[header] ||= []
          seen[header] << val
        end
        vals = seen.transform_values { |v| v.size == 1 ? v[0] : v }
        vals.each { |k, v| row[k] = v }
      end
    end

    def infer_encoding_or_default file
      if OS.linux? || OS.unix?
        return `file --mime #{file}`.strip.split('charset=').last
      elsif OS.mac?
        return `file -I #{file}`.strip.split('charset=').last
      end

      # Default
      Encoding.default_external.to_s
    end

    def converters
      funcs = []
      mthd = ActiveSupport::Inflector.method(:underscore)
      funcs << Proc.new { |field| mthd.call(field.gsub!(/ /, '_') || field) }
      funcs << Proc.new { |field| field.to_sym }
    end

    class ParserError < StandardError; end;
    class InvalidSourceCSVError < ParserError; end;
    class SchemaValidationFailedError < ParserError; end
    class NoHeadersProvidedError < ParserError; end
  end
end
