# frozen_string_literal: true

require 'amazing_print'
require 'active_support/core_ext/string/inflections'
require_relative 'meta_csv/version'
require_relative 'meta_csv/meta_csv_base'
require_relative 'meta_csv/parser'
require_relative 'meta_csv/transformer'
require_relative 'meta_csv/csv_data_manipulator'
require_relative 'meta_csv/standardizer'

module MetaCsv # :nodoc:
  class Manager
    CsvProps = Data.define(:old_headers, :new_headers, :source, :csv_table, :proc_csv_mem_efficient)
    StandardTransformation = Data.define(:column_order, :new_column_name, :invoke_standardization)
    class << self
      @@col_ord = 0

      def standardizing_definition
        @standardizing_definition ||= {}
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

      #########################################################################
      #          The definition in the schema file hooks into this method     #
      #########################################################################
      def validation_schema
        @user_schema = yield
      end

      attr_accessor :user_schema
    end

    def self.run(file_path:, transformations:, schema_file_path:)
      # We have a file called transformations.rb
      # The fill methods in that file hook into Manager.fill and add themselves into
      # standardizing_definition method

      raise 'no source CSV provided' unless File.exist? file_path
      raise 'transformations file doesnt exist' unless File.exist? transformations

      eval(File.open(transformations).read)

      # Always infer unless told otherwise
      source = MetaCsv_Base::INFER
      if schema_file_path
        eval(File.open(schema_file_path).read)
        source = MetaCSVBase::OTHER_CSV_SOURCE
      end

      nhn = standardizing_definition.keys

      defined_transformations_from_file = []
      standardizing_definition.each do |k, v|
        defined_transformations_from_file << StandardTransformation.new(new_column_name: k, column_order: v[0], invoke_standardization: v[1])
      end

      if !source in LEDGER_LIVE_CSV_SOURCE | COIN_TRACKER_CSV_SOURCE | TURBO_TAX_CSV_SOURCE | OTHER_CSV_SOURCE | INFER
        raise "Invalid CSV Source error"
      end

      ap user_schema

      result = Parser.new(file: file_path)

      m = CsvProps.new(
        old_headers: result.csv_table.headers,
        new_headers: nhn,
        source:,
        csv_table: result.csv_table,
        proc_csv_mem_efficient: result.csv_mem_efficient_iterator
      )

      ###################################################################################################
      # The validator can infer but otherwise will just validate using a schema and perform conversions #
      ###################################################################################################
      ValCoerc.run(csv_props: m, schema: user_schema, source:)

      ###########################################################################
      #     The standardizer localizes all of the information we might need     #
      ###########################################################################
      Standardizer.define_method(:old_headers, Proc.new { m.old_headers })
      Standardizer.define_method(:standardizing_functions, Proc.new { defined_transformations_from_file })
      Standardizer.define_method(:new_headers, Proc.new { m.new_headers })

      transformer = MetaCsv::Transformer.new(meta_csv: m)
      transformed_csv = transformer.run

      File.open((File.join(Dir.home, "transformed_csv_#{Time.now.strftime("%Y-%m-%d_%H_%M_%S")}.csv")), 'w') do |f|
        f.write transformed_csv
      end
    end
  end
end
