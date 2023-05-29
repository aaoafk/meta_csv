# frozen_string_literal: true

require_relative 'inferencer'
require_relative 'standardizer'
require 'refinements/hashes'

module MetaCsv
  class SchemaBuilder
    using Refinements::Hashes

    attr_accessor :schema, :headers, :schema_builder, :blueprint

    def initialize(headers:, blueprint:)
      @headers = headers
      @schema_builder = String.new
      @blueprint = blueprint
    end

    def build_schema
      # 1. predicates can be `required(:column_name).maybe(:column_type)` OR
      # 2. predicate can be `required(:column_name) (int? | float?)
      begin_schema_declaration!
      before_body_declaration!
      body_declaration!
      predicates_declaration!
      end_declaration!
      @schema = eval(schema_builder)
    end

    def begin_schema_declaration!
      begin_schema_declaration = "Dry::Schema.Params do\n"
      schema_builder << begin_schema_declaration
    end

    def before_body_declaration!
      schema_builder << "  before(:key_coercer) { |result| result.to_h.symbolize_keys! }\n"
    end

    def body_declaration!
      schema_builder << "  required(:body).array(:hash) do\n"
    end

    def predicates_declaration!
      headers.each do |col_name|
        inferred_types_for_column = blueprint[col_name]
        types_for_predicate = []
        inferred_types_for_column.each_with_index do |v, idx|
          # "Float", "Integer", "Date", "String"
          case idx
          when 0 # Float
            types_for_predicate << Float if v > 0.0
          when 1 # Integer
            types_for_predicate << Integer if v > 0.0
          when 2 # Date
            types_for_predicate << Date if v > 0.0
          when 3 # String
            types_for_predicate << String if v > 0.0
          end
        end

        case types_for_predicate.size
        when 1
          predicate_type(column_name: col_name, types: types_for_predicate)
        else
          predicate_types(column_name: col_name, types: types_for_predicate)
        end
      end
    end

    def predicate_type(column_name:, types:)
      schema_builder << "    required(:#{column_name}).maybe(:#{dry_inferred_type(types[0])})\n"
    end

    def predicate_types(column_name:, types:)
      schema_builder << "    required(:#{column_name}) {"
      types.each_with_index do |t, idx|
        schema_builder << " #{dry_inferred_type_for_predicate(t)} |" if (idx < types.size - 2)
        schema_builder << " #{dry_inferred_type_for_predicate(t)}" if (idx == types.size - 1)
      end
      schema_builder << "}\n"
    end

    def dry_inferred_type_for_predicate el
      if el == Integer
        'int?'
      elsif el == Float
        'float?'
      elsif el == String
        'str?'
      else
        'date?'
      end
    end

    def dry_inferred_type el
      if el == Integer
        'integer'
      elsif el == Float
        'float'
      elsif el == Date
        'date'
      else
        'string'
      end
    end

    def end_declaration!
      schema_builder << "  end\n"
      schema_builder << "end\n"
    end

  end
end
