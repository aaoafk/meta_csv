# frozen_string_literal: true

require 'time'
require_relative 'standardizer'

module MetaCsv
  class Inferencer

    def averages_for_types_of_csv_chunks
      @averages_for_types_of_csv_chunks ||= []
    end

    class << self
      def averages_for_types_of_csv_chunks
        @averages_for_types_of_csv_chunks ||= []
      end

      def log_average_for_csv_chunk el
        averages_for_types_of_csv_chunks << el
      end
    end

    def self.infer_type_for_chunk chunk
      inferred_types_for_columns = {}
      # Set column access
      chunk.rows.headers.each do |header|
        types_seen = Hash.new(0)
        chunk.rows[header].each do |v|
          if v =~ /^[-+]?[0-9]*\.[0-9]+$/
            types_seen[Float.to_s] ||= 0
            types_seen[Float.to_s] += 1
          elsif v =~ /^\d+$/
            types_seen[Integer.to_s] ||= 0
            types_seen[Integer.to_s] += 1
          elsif v.is_a? Date
            types_seen[Date.to_s] ||= 0
            types_seen[Date.to_s] += 1
          else
            types_seen[String.to_s] ||= 0
            types_seen[String.to_s] += 1
          end
        end
        # Divide the number by total cells to get the average
        total = chunk.rows[header].size
        values = types_seen.values_at("Float", "Integer", "Date", "String")
        # Values -> [Mean of # Floats seen, Mean of # Integers seen, Mean of # Date seen, Mean of # String seen]
        values = values.map { |v| (v * 1.0) / total }
        inferred_types_for_columns.fetch(header) { |k| inferred_types_for_columns[k] = values }
      end
      inferred_types_for_columns
    end

    # A cell responds to header and value
    def infer_types_for_cells cells
      inferred_types_for_headers = {}
      cells.each do |cell|
        ap cell.value
        if cell.value =~ /^[-+]?[0-9]*\.[0-9]+$/
          inferred_types_for_headers[cell.header] = Float
        elsif cell.value =~ /^\d+$/
          inferred_types_for_headers[cell.header] = Integer
        elsif (date_format = matches_date_format?(cell.value))
          inferred_types_for_headers[cell.header] = [Date, date_format]
        else
          inferred_types_for_headers[cell.header] = String
        end
      end
      inferred_types_for_headers.freeze
    end

    def self.infer_types_for_column_cells(values:)
    end

    def matches_date_format? val
      DATE_FORMATS.each do |_, v|
        Date.strptime(val, v) rescue next
        return v
      end
      nil
    end

    def self.matches_date_format? val

      date_formats.each do |_, v|
        Date.strptime(val, v) rescue next
        return v
      end
      nil
    end
  end
end
