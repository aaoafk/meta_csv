# frozen_string_literal: true

require 'csv'
require 'active_support/core_ext/string/inflections'
require_relative 'meta_csv_base'
require_relative 'os'

module MetaCsv
  class Parser # :nodoc:
    include MetaCsvBase

    attr_accessor :csv_table, :headers
    attr_reader :csv_mem_efficient_iterator

    def initialize(file:)

      @source = source
      @schema = schema
      @csv_table = initialize_body file
      @csv_mem_efficient_iterator = initialize_enumerator file
    end

    private

    def initialize_body file
      f = File.open(file)
      # Determine encoding
      inferred_encoding = infer_encoding_or_default file

      # The instance allows us to cache a CSV object for retrieval if we use the same headers
      CSV.instance f, encoding: inferred_encoding, headers: true, header_converters: converters, skip_blanks: true
      res = CSV.instance(f, encoding: inferred_encoding, headers: true, header_converters: converters, skip_blanks: true).read

      # Remove duplicate rows from further processing
      res = res.to_a.uniq! || res

      # Resolve duplicate headers by grabbing the first value or everything
      res.each_with_index do |row, idx|
        seen = {}
        row.each_pair do |col, val|
          seen[col] ||= []
          seen[col] << val
        end
        res[idx] = seen.transform_values { |v| v.size == 1 ? v[0] : v }.to_a
      end

      res
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

    def initialize_enumerator file
      CSV.foreach file, headers: true, header_converters: converters
    end

    def converters
      mthd = ActiveSupport::Inflector.method(:underscore)
      Proc.new { |field| mthd.call field.gsub!(/ /, '_') || field }
    end

    class ParserError < StandardError; end;
    class InvalidSourceCSVError < ParserError; end;
    class SchemaValidationFailedError < ParserError; end
    class NoHeadersProvidedError < ParserError; end
  end
end
