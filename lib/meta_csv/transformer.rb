# frozen_string_literal: true

require_relative 'meta_csv_base'
require_relative 'standardizer'
require_relative 'row_cell_mapper'

module MetaCsv 
  class Transformer # :nodoc:
    include MetaCsvBase

    attr_reader :standardizer

    def initialize(meta_csv:, standardizer:)
      @meta_csv = meta_csv
      @standardizer = standardizer
    end

    def run
      standardize_csv 
    end

    private

    attr_reader :meta_csv

    def standardize_csv
      row_mapper = RowCellMapper.new(meta_csv)
      CSV.generate do |new_csv|
        new_csv << standardizer.new_headers.map { |el| (el.gsub(/_/, ' ') || el).titleize }
        #######################################################################
        #               foreach is efficient for giant csv files              #
        #######################################################################
        meta_csv.each do |el|
          row_mapper.curr_row = el
          transformed_row = CSV::Row.new(standardizer.new_headers, row_mapper.standardize_row)
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

