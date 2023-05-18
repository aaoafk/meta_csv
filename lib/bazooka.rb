# frozen_string_literal: true

require 'amazing_print'
require 'active_support/core_ext/string/inflections'
require_relative 'bazooka/version'
require_relative 'bazooka/bazooka_base'
require_relative 'bazooka/parser'
require_relative 'bazooka/transformer'
require_relative 'bazooka/csv_data_manipulator'
require_relative 'bazooka/standardizer'

module Bazooka # :nodoc:
  class Manager

    class << self
      @@col_ord = 0
      def standardizing_definition 
        @standardizing_defintion ||= {}
      end

      #######################################################################################
      # DSL that maps the { new_column_name => [column_order, proc] that handles transactions #
      #######################################################################################
      def fill_column(new_column_name, &blk)
        new_column_name.gsub!(/ /, '_')
        ncn = new_column_name.underscore
        standardizing_definition.fetch(ncn) { |k| standardizing_definition[k] = [@@col_ord, blk] }
        @@col_ord += 1
      end
    end

    # We have a file called transformations.rb
    # The fill methods in that file hook into Manager.fill and add themselves into
    # standardizing_definition method
    raise "transformations file doesn't exist" unless File.exist?(File.join(File.dirname(__FILE__), 'transformations.rb'))

    eval(File.open(File.join(File.dirname(__FILE__), 'transformations.rb')).read)

    nhn = standardizing_definition.keys

    StandardTransformation = Struct.new(:column_order, :new_column_name, :invoke_standardization)
    defined_transformations_from_file = []
    standardizing_definition.each do |k, v|
      defined_transformations_from_file << StandardTransformation.new(new_column_name: k, column_order: v[0], invoke_standardization: v[1])
    end

    ap BazookaBase::LedgerLiveValidationSchema.is_a? Dry::Schema::Params
    result = Parser.new(schema: BazookaBase::LedgerLiveValidationSchema,
                        source: BazookaBase::OTHER_CSV_SOURCE,
                        file: "/home/sf/Documents/ledgerlive-operations-2023.03.17.csv")
    
    MetaCsv = Data.define(:old_headers, :new_headers, :source, :csv_table, :proc_csv_mem_efficient)
    m = MetaCsv.new(
      old_headers: result.csv_table.headers,
      new_headers: nhn,
      source: result.source,
      csv_table: result.csv_table,
      proc_csv_mem_efficient: result.csv_mem_efficient_iterator
    )

    ###########################################################################
    #     The standardizer localizes all of the information we might need     #
    ###########################################################################
    Standardizer.define_method(:old_headers, Proc.new { m.old_headers })
    Standardizer.define_method(:standardizing_functions, Proc.new { defined_transformations_from_file })
    Standardizer.define_method(:new_headers, Proc.new { m.new_headers })

    transformer = Bazooka::Transformer.new(meta_csv: m)
    transformer.run
  end
end
