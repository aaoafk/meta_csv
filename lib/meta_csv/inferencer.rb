# frozen_string_literal: true

require 'time'
require_relative 'standardizer'

module MetaCsv
  class Inferencer

    class << self
    end

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
      chunk.rows.by_col!
      chunk.rows.headers.each do |header|
        types_seen = infer_types_for_column_cells(values: chunk.rows[header])
        # Divide the number by total cells to get the average
        total = chunk.rows[header].size
        values = types_seen.values_at "Float", "Integer", "Date", "String"
        # Values -> [Mean of # Floats seen, Mean of # Integers seen, Mean of # Date seen, Mean of # String seen]
        values.map! { |v| (v * 1.0) / total }
        inferred_types_for_columns.fetch(header) { |k| inferred_types_for_columns[k] = values }
      end
      ap inferred_types_for_columns
      # write the result of this inference to inferred_schemas
      # how is merging going to be done?
      # averages_for_types_of_csv_chunks << inferred_types_for_columns

      # reset access mode to row
      chunk.rows.by_row!
    end
    # DateTime.rfc3339

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
      type_tracker = Hash.new(0)
      values.each do |v|
        if v =~ /^[-+]?[0-9]*\.[0-9]+$/
          type_tracker[Float.to_s] ||= 0
          type_tracker[Float.to_s] += 1
        elsif v =~ /^\d+$/
          type_tracker[Integer.to_s] ||= 0
          type_tracker[Integer.to_s] += 1
        elsif matches_date_format? v
          type_tracker[Date.to_s] ||= 0
          type_tracker[Date.to_s] += 1
        else
          type_tracker[String.to_s] ||= 0
          type_tracker[String.to_s] += 1
        end
      end
      type_tracker
    end

    def matches_date_format? val
      DATE_FORMATS.each do |_, v|
        Date.strptime(val, v) rescue next
        return v
      end
      nil
    end

    def self.matches_date_format? val
      date_formats = {
        'rfc3339' => '%FT%T',
        'slash_m_d_y4' => '%m/%d/%Y',
        'slash_m_d_y2' => '%m/%d/%y',
        'slash_d_m_y4' => '%d/%m/%Y',
        'slash_d_m_y2' => '%d/%m/%y',
        'dash_d_m_y4' => '%d-%m-%Y',
        'dash_d_m_y2' => '%d-%m-%y',
        'dash_m_d_y4' => '%m-%d-%Y',
        'dash_m_d_y2' => '%m-%d-%y',
        'dash_y4_m_d' => '%Y-%m-%d',
        'slash_m1_d_y4' => '%f/%e/%Y',
        'slash_m1_d_y2' => '%f/%e/%y',
        'slash_d_m1_y4' => '%e/%f/%Y',
        'slash_d_m1_y2' => '%e/%f/%y',
        'dash_m1_d_y4' => '%f-%e-%Y',
        'dash_m1_d_y2' => '%f-%e-%y',
        'dash_d_m1_y4' => '%e-%f-%Y',
        'dash_d_m1_y2' => '%e-%f-%y',
        'dash_mth_d_y4' => '%b %e, %Y',
        'dash_month_d_y4' => '%B %d, %Y',
        'dash_y4_m2_d2_H_M_S' => '%Y-%m-%d %H:%M:%S',
        'dash_H_M_S' => '%H:%M:%S',
        'dash_y4_m2_d2_H_M_S_MS' => '%Y-%m-%d %I:%M:%S %p'
      }

      date_formats.each do |_, v|
        Date.strptime(val, v) rescue next
        return v
      end
      nil
    end
  end
end
