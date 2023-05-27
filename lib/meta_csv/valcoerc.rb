# frozen_string_literal: true

require_relative 'inferencer'
require_relative 'meta_csv_base'

module MetaCsv
  class ValCoerc
    include MetaCsvBase
    attr_accessor :schema, :csv_props, :date_format, :dried_csv, :columns_with_multiple_values
    attr_reader :header_to_type

    Cell = Data.define :header, :value
    # csv_props has most of the information we need
    def run(csv_props:, user_schema:)
      @csv_props = csv_props
      @header_to_type = infer_types_for_data(element_to_infer_from) unless schema

      # Dynamically build the schema in build_schema if we don't get one
      build_schema unless user_schema
      initialize_schema

      # Build the array of hashes that dry can ingest
      @dried_csv = dry_csv_structure

      validate_using_schema
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

    # The issue with this is that it assumes that one row is representative of the type state
    # for every row...

    # Columns can have mixed types... How should we deal with columns with mixed types
    def infer_types_for_data column_to_singular_value
      cells = []
      column_to_singular_value.each do |k, v|
        cells << Cell.new(header: k, value: v)
      end
      Inferencer.infer_types_for_cells cells
    end

    # Because we wrap duplicate values we need to make sure that they are accounted for here...
    def element_to_infer_from
      seen = {}
      unseen = csv_props.old_headers
      multiple_value_columns = []
      while (looking_for = unseen.pop)
        csv_props.csv_table.each do |row|
          next if row[looking_for].nil?
          if (idx = row[looking_for].index(','))
            seen[looking_for] = row[looking_for][0...idx]
            multiple_value_columns << looking_for
            break
          end
          seen[looking_for] = row[looking_for]
          break
        end
      end

      @columns_with_multiple_values = multiple_value_columns
      seen
    end

    # Build a schema with column names that are snakified and types that are inferred

    using Refinements::Hashes
    def build_schema
      # 1. strings are of the form `required(:column_name).maybe(:column_type)`
      schema_builder = String.new
      begin_schema_declaration = "schema = Dry::Schema.Params do\n"
      schema_builder << begin_schema_declaration
      schema_builder << "  before(:key_coercer) { |result| result.to_h.symbolize_keys! }\n"
      schema_builder << "  required(:body).array(:hash) do\n"
      csv_props.csv_table.headers.each do |el|
        # header_to_type[el] is a constant that needs to be converted to the symbol that dry understands
        str_type = dry_inferred_type(header_to_type[el])
        schema_builder << "    required(:#{el}).maybe(:#{str_type})\n"
      end
      schema_builder << "  end\n"
      schema_builder << "end\n"
      @schema = eval(schema_builder)
      ap schema
      exit
    end

    def dry_inferred_type el
      if el == Integer
        'integer'
      elsif el == Float
        'float'
      elsif el == String
        'string'
      else
        @date_format = el[1]
        'date_time'
      end
    end

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

    #########################################################################
    #       Transform CSV into data structure acceptable by dry-schema       #
    #########################################################################
    def dry_csv_structure
      res = Array.new
      csv_props.csv_table.each { |el| res << el.to_h }
      res
    end

    class ValCoercError < ::StandardError; end
    class SchemaValidationFailedError < ValCoercError; end
  end
end
