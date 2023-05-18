# frozen_string_literal: true

require_relative 'bazooka_base'
require_relative 'standardizer'
require_relative 'transaction_data_mapper'

module Bazooka
  class Transformer # :nodoc:
    include BazookaBase

    attr_accessor :standardize_functions, :transformed_csv, :new_headers, :old_headers, :meta_csv
    attr_reader :standardizer

    def initialize(meta_csv:)
      # validate_sources([from_source, to_source])
      @meta_csv = meta_csv
      @standardizer = Standardizer.instance
    end

    def run 
      standardize_csv 
    end

    private

    # def init_standardizer standard_definition
    #   unwrap standard_definition

    #   transformations.each do |t|
    #     Standardizer.define_method(
    #       "#{t.column_order}_bazooka_fill_#{t.new_column_name}".to_sym,
    #       t.standardizing_lambda
    #     )
    #   end
    #   Standardizer.instance
    # end

    # All the information we need is in Meta_CSV and Standardizer we can reduce this to just access those objects

    # : old_column_name, new_column_name, standardizing_function
    # ColumnTransformation = Struct.new :column_order, :new_column_name, :standardizing_lambda
    # def unwrap standard_definition
    #   raise InvalidStandardDefinition unless standard_definition.is_a? Hash

    #   standard_definition.each_with_index do |el, idx|
    #     #                   String              Proc
    #     # where el is { new_column_name => Proc(transaction) }
    #     raise InvalidStandardizingFunction unless el[1].is_a? Proc

    #     transformations << ColumnTransformation.new(
    #       idx,
    #       el[0],
    #       el[1]
    #     )
    #   end
    # end

    def standardize_csv
      transaction_mapper = TransactionDataMapper.new(meta_csv)
      CSV.generate do |new_csv|
        new_csv << standardizer.new_headers.clone.map! { |el| (el || el.gsub!(/_/, ' ')).titleize }
        #######################################################################
        #               foreach is efficient for giant csv files              #
        #######################################################################
        meta_csv.proc_csv_mem_efficient.each do |el|
          transaction_mapper.transaction = el
          transformed_row = CSV::Row.new(standardizer.new_headers, transaction_mapper.standardize_transaction)
          new_csv << transformed_row.fields
        end
      end
    end

    class TransformationError < StandardError; end
    class InvalidSource < TransformationError; end
    class InvalidTransformationObjectError < TransformationError; end
    class InvalidCsvRowTransformationError < TransformationError; end
    class InvalidCsvHeadersForTransformationError < TransformationError; end
    class InvalidStandardDefinition < TransformationError; end
    class InvalidStandardizingFunction < TransformationError; end
  end
end
