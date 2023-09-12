# frozen_string_literal: true

require_relative "helpers"

module MetaCsv
  class Blueprint
    include Helpers

    ColumnStandardizer = column_transform_obj

    # REVIEW: `standardizing_definition` is the information extracted from `define_column`
    # `standard_transformations` is a data structure that wraps each definition
    # with messages to make the meaning of the structure clear...
    attr_accessor :standardizing_definition, :standard_transformations, :column_order

    def initialize(transformations_file:)
      @standardizing_definition = {}
      @standard_transformations = []
      @column_order = 0 # => Used to ensure that the column order is written as expected, removed later
      eval_transformations_file(file: transformations_file) # => Returns self
    end

    def new_column_names
      standardizing_definition.keys
    end

    private
    
    def eval_transformations_file(file:)
      contents = Helpers.read_file(file)
      instance_eval(contents.dup.tap { |kode| kode.untaint if RUBY_VERSION < "2.7" }, file.to_s, 1) # => `instance_eval` to hook into `fill_column`
      after_instance_eval
    end

    #######################################################################################
    # DSL function maps the { new_column_name => [column_order, proc]                     #
    #######################################################################################
    def define_column(new_column_name, &blk)
      new_column_name = Helpers.underscore new_column_name
      standardizing_definition.fetch(new_column_name) { |k| standardizing_definition[k] = [column_order, blk] } # => blk is converted to a proc
      column_order += 1
    end

    def after_instance_eval
      standardizing_definition.each do |k, v|
        standard_transformations << ColumnStandardizer.new(new_column_name: k, column_order: v[0], invoke_standardization: v[1])
      end

      # Remove transient instance variables
      remove_instance_variable :@column_order
    end

    def column_transform_obj
      if RUBY_VERSION > "3.2"
        Data.define(:column_order, :new_column_name, :invoke_standardization)
      else
        Struct.new(:column_order, :new_column_name, :invoke_standardization)
      end
    end
  end
end
