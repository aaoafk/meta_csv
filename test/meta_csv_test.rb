# frozen_string_literal: true

require 'test/unit'
require_relative '../lib/meta_csv'

module MetaCsv
  class MetaCsvTest < Test::Unit::TestCase
    attr_accessor :test_files

    def setup
      @test_files = Dir.glob('csv_test_data/*').each do |f|
        File.absolute_path(f, "~")
      end
    end

    def test_large_csv_file
      file_path = '/home/sf/csv_test_data/large_csv_file.csv'
      transformations = '/home/sf/Development/meta_csv/lib/transformations.rb'
      schema_file_path = ''
      MetaCsv::Manager.run(file_path:, transformations:, schema_file_path:)
    end

    def test_csv_file_with_multiple_types_for_column
      file_path = '/home/sf/csv_test_data/ledgerlive-operations-2023.03.17.csv'
      transformations = '/home/sf/Development/meta_csv/lib/transformations.rb'
      schema_file_path = ''
      MetaCsv::Manager.run(file_path:, transformations:, schema_file_path:)
    end
  end
end
