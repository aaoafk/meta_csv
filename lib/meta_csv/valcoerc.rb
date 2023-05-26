# frozen_string_literal: true

require_relative 'inferencer'
require_relative 'meta_csv_base'

module MetaCSV
  module ValCoerc
    include MetaCsvBase
    class << self
      attr_accessor :schema, :source, :meta_csv_props, :date_format, :dried_csv
      attr_reader :header_to_type

      # csv_props has most of the information we need
      def run(csv_props:, schema:, source:)
        @csv_props = csv_props
        @source = source
        @header_to_type = infer_types_from_csv_row(csv_props.csv_table[1]) unless schema

        # if schema is provided then just validate using it.
        # Dynamically build the schema in build_schema
        @schema = schema || build_schema(params: csv_props.old_headers)

        @dried_csv = dry_csv
        # We need to coerce types here using a schema if we want to use values reliably in transformer
        validate_using_schema
      end

      def validate_using_schema
        case source
        when LEDGER_LIVE_CSV_SOURCE
          verify_schema_transform(schema_validation_result: LedgerLiveValidationSchema.call(body: result).to_monad)
        when TURBO_TAX_CSV_SOURCE
          verify_schema_transform(schema_validation_result: TurboTaxValidationSchema.call(body: result).to_monad)
        when COIN_TRACKER_CSV_SOURCE 
          verify_schema_transform(schema_validation_result: CoinTrackerValidationSchema.call(body: result).to_monad)
        when OTHER_CSV_SOURCE 
          verify_schema_transform(schema_validation_result: OtherValidationSchema.call(body: result).to_monad)
        when INFER
          verify_schema_transform(schema_validation_result: InferredSchema.call(body: result).to_monad)
        else
          warn 'did not validate using schema because the source was not set... continuing execution...'
        end
      end

      def verify_schema_transform(schema_validation_result:)
        case schema_validation_result
        in Success(result) then return
        in Failure(result) then raise SchemaValidationFailedError.new(msg: ap(result))
        end
      end

      Cell = Data.define :header, :value
      def infer_types_from_csv_row csv_row
        cells = []
        csv_row.each_pair do |k, v|
          cells << Cell.new(header: k, value: v[1])
        end
        Inferencer.infer_types_for_csv_row cells
        # build_schema_from_inferred_types(types: inferred_types_for_row)
      end

      # Build a schema with column names that are snakified and types that are inferred
      def build_schema(params:)
        # 1. strings are of the form `required(:column_name).maybe(:column_type)`
        begin_schema_declaration = "schema = Dry::Schema.Params do \n"
        schema << begin_schema_declaration
        params.each do |el|
          # header_to_type[el] is a constant that needs to be converted to the symbol that dry understands
          schema << "required(:#{el}).maybe(:#{dry_inferred_type(header_to_type[el])})\n"
        end
        schema << "end"

        initialize_schema
      end

      def dry_inferred_type el
        case el
        in Integer
          'integer'
        in Float
          'float'
        in String
          'string'
        in [Date, date_format_str]
          @date_format = date_format_str
          'datetime'
        end
      end

      def initialize_schema
        case source
        when LEDGER_LIVE_CSV_SOURCE
          LedgerLiveValidationSchema
        when COIN_TRACKER_CSV_SOURCE
          CoinTrackerValidationSchema
        when TURBO_TAX_CSV_SOURCE
          TurboTaxValidationSchema
        when OTHER_CSV_SOURCE
          raise InvalidSchemaObjectError unless schema.is_a?(Dry::Schema::Params)
          const_set('OtherValidationSchema', schema)
        when INFER
          const_set('InferredSchema', eval(schema))
        end
      end
    end
  end
end
