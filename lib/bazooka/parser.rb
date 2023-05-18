# frozen_string_literal: true

require 'csv'
require 'active_support/core_ext/string/inflections'
require_relative 'bazooka_base'
require_relative 'standardizer'

# MetaCSV data point that stores old headers and to headers
module Bazooka
  class Parser # :nodoc:
    include BazookaBase

    attr_accessor :csv_table, :headers
    attr_reader :schema, :client, :source, :csv_mem_efficient_iterator

    def initialize(schema:, source:, file:)
      if !source in LEDGER_LIVE_CSV_SOURCE | COIN_TRACKER_CSV_SOURCE | TURBO_TAX_CSV_SOURCE | OTHER_CSV_SOURCE
        raise InvalidSourceCSVError
      end

      @source = source
      @schema = initialize_schema schema
      @csv_table = initialize_body file
      @csv_mem_efficient_iterator = initialize_enumerator file
    end

    private

    def initialize_body file
      f = File.open(file)
      #########################################################################
      #      The instance allows us to cache this obj and retrieve it quickly?#
      #########################################################################
      CSV.instance(f,
                   headers: true,
                   header_converters: converters)
      CSV.parse f, headers: true, header_converters: converters
      # TODO: Look at validation
      # validate(data.map(&:to_h))
    end

    def initialize_enumerator file
      CSV.foreach file, headers: true, header_converters: converters
    end
    def converters
      mthd = ActiveSupport::Inflector.method(:underscore)
      Proc.new { |field| mthd.call field.gsub!(/ /, '_') || field }
    end

    def initialize_schema schema
      case source 
      when LEDGER_LIVE_CSV_SOURCE
        return LedgerLiveValidationSchema
      when COIN_TRACKER_CSV_SOURCE
        return CoinTrackerValidationSchema
      when TURBO_TAX_CSV_SOURCE
        return TurboTaxValidationSchema
      when OTHER_CSV_SOURCE
        raise InvalidSchemaObjectError unless schema.is_a? Dry::Schema::Params
        schema
      end
    end

    def initialize_headers 
      case source
      when LEDGER_LIVE_CSV_SOURCE
        LEDGER_LIVE_CSV_ROW_HEADERS
      when TURBO_TAX_CSV_SOURCE
        TURBO_TAX_CSV_ROW_HEADERS
      when COIN_TRACKER_CSV_SOURCE
        COIN_TRACKER_CSV_ROW_HEADERS
      when OTHER_CSV_SOURCE
        other_csv_row_headers = headers
        other_csv_row_headers.freeze
      end
    end

    def validate(result)
      case source
      when LEDGER_LIVE_CSV_SOURCE
        verify_schema_transform(schema_validation_result: LedgerLiveValidationSchema.call(body: result).to_monad)
      when TURBO_TAX_CSV_SOURCE
        verify_schema_transform(schema_validation_result: TurboTaxValidationSchema.call(body: result).to_monad)
      when COIN_TRACKER_CSV_SOURCE 
        verify_schema_transform(schema_validation_result: CoinTrackerValidationSchema.call(body: result).to_monad)
      else
        verify_schema_transform(schema_validation_result: OtherValidationSchema.call(body: result).to_monad)
      end
    end

    def verify_schema_transform(schema_validation_result:)
      case schema_validation_result
      in Success(result) then return
      in Failure(result) then raise SchemaValidationFailedError.new(msg: ap(result))
      end
    end

    class ParserError < StandardError; end;
    class InvalidSourceCSVError < ParserError; end;
    class InvalidSchemaObjectError < ParserError; end
    class SchemaValidationFailedError < ParserError; end
    class NoHeadersProvidedError < ParserError; end
  end
end
