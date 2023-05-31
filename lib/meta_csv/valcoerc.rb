# frozen_string_literal: true

require_relative 'inferencer'
require_relative 'meta_csv_base'

module MetaCsv
  class ValCoerc
    include MetaCsvBase
    attr_accessor :csv_props, :dried_csv
    attr_reader :header_to_type

    class << self

      def run csv_chunks
        # Build the array of hashes that dry can ingest
        @dried_csv = dry_csv_structure

        validate_using_schema
      end

      #########################################################################
      #       Transform CSV into data structure acceptable by dry-schema       #
      #########################################################################
      def dry_csv_structure
        res = Array.new
        csv_props.csv_table.each { |el| res << el.to_h }
        res
      end
    end


    def validate_using_schema
      case csv_props.source
      when LEDGER_LIVE_CSV_SOURCE
        verify_schema_transform(schema_validation_result: LedgerLiveValidationSchema.call(body: dried_csv).to_monad)
      when TURBO_TAX_CSV_SOURCE
        verify_schema_transform(schema_validation_result: TurboTaxValidationSchema.call(body: dried_csv).to_monad)
      when COIN_TRACKER_CSV_SOURCE 
        verify_schema_transform(schema_validation_result: CoinTrackerValidationSchema.call(body: dried_csv).to_monad)
      when OTHER_CSV_SOURCE 
        verify_schema_transform(schema_validation_result: OtherValidationSchema.call(body: dried_csv).to_monad)
      when INFER
        verify_schema_transform(schema_validation_result: InferredSchema.call(body: dried_csv).to_monad)
      else
        warn 'did not validate using schema because the source was not set... continuing execution...'
      end
    end

    def verify_schema_transform(schema_validation_result:)
      case schema_validation_result
      in Success(result) then return result.to_h[:body]
      in Failure(result) then raise SchemaValidationFailedError.new(msg: ap(result.errors.to_h))
      end
    end


    # Build a schema with column names that are snakified and types that are inferred

    def initialize_schema
      case csv_props.source
      when LEDGER_LIVE_CSV_SOURCE
        LedgerLiveValidationSchema
      when COIN_TRACKER_CSV_SOURCE
        CoinTrackerValidationSchema
      when TURBO_TAX_CSV_SOURCE
        TurboTaxValidationSchema
      when OTHER_CSV_SOURCE
        raise InvalidSchemaObjectError unless schema.is_a?(Dry::Schema::Params)
        ValCoerc.const_set('OtherValidationSchema', schema)
      when INFER
        ValCoerc.const_set('InferredSchema', schema)
      end
    end


    class ValCoercError < ::StandardError; end
    class SchemaValidationFailedError < ValCoercError; end
  end
end
