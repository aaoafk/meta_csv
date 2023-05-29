# frozen_string_literal: true

require 'amazing_print'
require 'active_support/core_ext/string/inflections'
require 'parallel'
require_relative 'meta_csv/version'
require_relative 'meta_csv/meta_csv_base'
require_relative 'meta_csv/parser'
require_relative 'meta_csv/transformer'
require_relative 'meta_csv/csv_data_manipulator'
require_relative 'meta_csv/standardizer'
require_relative 'meta_csv/valcoerc'
require_relative 'meta_csv/schema_builder'

module MetaCsv # :nodoc:
  class Manager
    CsvProps = Data.define(:old_headers, :new_headers, :source, :inferred_encoding)
    StandardTransformation = Data.define(:column_order, :new_column_name, :invoke_standardization)
    include MetaCsvBase
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

      def seesaw_ractor!(collection:, method:)
        collection.each do |el|
          el.rows.send method
        end
      end
    end

    def self.run(file_path:, transformations:, schema_file_path:)
      # We have a file called transformations.rb
      # The fill methods in that file hook into Manager.fill and add themselves into
      # standardizing_definition method

      raise 'no source CSV provided' unless File.exist? file_path
      raise 'transformations file doesnt exist' unless File.exist? transformations

      eval(File.open(transformations).read)

      # Always infer unless told otherwise
      source = INFER
      if !schema_file_path.empty?
        eval(File.open(schema_file_path).read)
        source = OTHER_CSV_SOURCE
      end

      nhn = standardizing_definition.keys

      defined_transformations_from_file = []
      standardizing_definition.each do |k, v|
        defined_transformations_from_file << StandardTransformation.new(new_column_name: k, column_order: v[0], invoke_standardization: v[1])
      end

      if !source in LEDGER_LIVE_CSV_SOURCE | COIN_TRACKER_CSV_SOURCE | TURBO_TAX_CSV_SOURCE | OTHER_CSV_SOURCE | INFER
        raise 'Invalid CSV Source error'
      end

      result = Parser.new(file: file_path)

      # result.csv_chunks.each do |chunk|
      #   chunk.rows.each do |row|
      #     ap row
      #   end
      # end

      m = CsvProps.new(
        old_headers: result.csv_chunks[0].rows.headers,
        new_headers: nhn,
        source:,
        inferred_encoding: result.inferred_encoding
      )

      ###########################################################################
      #     The standardizer localizes some information we might need           #
      ###########################################################################

      Standardizer.define_method(:old_headers, Proc.new { m.old_headers })
      Standardizer.define_method(:standardizing_functions, Proc.new { defined_transformations_from_file })
      Standardizer.define_method(:new_headers, Proc.new { m.new_headers })
      Standardizer.define_method(:inferred_encoding, Proc.new { m.inferred_encoding })

      #########################################################################
      #    Ractors can't invoke `!' methods, i.e. setters and other things    #
      #########################################################################
      seesaw_ractor!(collection: result.csv_chunks, method: :by_col!)
      mean_types_for_csv_row_chunks = ::Parallel.map(result.csv_chunks, in_ractors: OS.cores, ractor: [Inferencer, :infer_type_for_chunk], progress: true)
      seesaw_ractor!(collection: result.csv_chunks, method: :by_row!)

      # The master_schema has the inferred types across all chunks.
      Inferencer.merge_inferred_types mean_types_for_csv_row_chunks

      #########################################################################
      #         ValCoerc will coerce values using the inferred schema         #
      #########################################################################
      blueprint = user_schema if source == OTHER_CSV_SOURCE
      blueprint = Inferencer.master_schema if source == INFER

      ap blueprint
      sb = SchemaBuilder.new(headers: Standardizer.instance.old_headers, blueprint:)
      sb.build_schema
      ap sb.schema, indent: -2, class: Dry::Schema::Params
      exit
      coerced_csv = ValCoerc.new.run(csv_chunks: , user_schema:)

      # coerced_csv needs to be a CSV table?
      transformer = Transformer.new(meta_csv: coerced_csv)
      transformed_csv = transformer.run

      ap transformed_csv
      File.open((File.join(Dir.home, "transformed_csv_#{Time.now.strftime("%Y-%m-%d_%H_%M_%S")}.csv")), 'w') do |f|
        f.write transformed_csv
      end
    end
  end
end
