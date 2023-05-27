# frozen_string_literal: true

require 'csv'
require 'active_support/core_ext/string/inflections'
require_relative 'meta_csv_base'
require_relative 'os'
require 'parallel'

module MetaCsv
  class Parser # :nodoc:
    include MetaCsvBase

    BATCH_SIZE = 2048
    CPUS_AVAILABLE = OS.cores

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

      ::Parallel.map(csv_chunks, in_ractors: CPUS_AVAILABLE, ractor: [Parser, :process_chunks])
      ::Parallel.map(csv_chunks, in_ractors: CPUS_AVAILABLE, ractor: [Parser, :shuffle_chunk_data])
    end

    def self.shuffle_chunk_data chunk
      data = chunk.rows
      data.to_a.shuffle
    end

    def self.process_chunks chunk
      # Remove duplicate rows from further processing
      data = chunk.rows
      data = data.to_a.uniq! || data

      # resolve duplicate headers by grabbing the first value or everything
      data.each_with_index do |row, _|
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
