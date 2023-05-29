# frozen_string_literal: true

require 'time'
require_relative 'standardizer'

module MetaCsv
  class Inferencer

    class << self
      attr_accessor :master_schema
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
          elsif matches_date_format? v
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

    def self.merge_inferred_types inferred_types_for_chunks
      num_of_chunks = inferred_types_for_chunks.size
      master_inferred_types = {}
      
      # 1. Each hash is already a mean so we will be taking a mean of means
      inferred_types_for_chunks.each do |el|
        master_inferred_types.merge!(el) do |key, old_value, new_value|
          master_inferred_types[key] = [
            old_value[0] + new_value[0],
            old_value[1] + new_value[1],
            old_value[2] + new_value[2],
            old_value[3] + new_value[3],
          ]
        end
      end

      master_inferred_types.transform_values do |value|
        value.map! { |mean_of_means| mean_of_means / num_of_chunks }
      end

      @master_schema = master_inferred_types
    end

    # Because we wrap duplicate values we need to make sure that they are accounted for here...

    ###########################################################################
    #              Was using this to find multiple value columns              #
    ###########################################################################
    def element_to_infer_from
      seen = {}
      unseen = csv_props.old_headers
      multiple_value_columns = []
      while (looking_for = unseen.pop)
        csv_props.csv_table.each do |row|
          next if row[looking_for].nil?
          if (idx = row[looking_for].index(','))
            seen[looking_for] = row[looking_for][0...idx]
            multiple_value_columns << looking_for
            break
          end
          seen[looking_for] = row[looking_for]
          break
        end
      end

      @columns_with_multiple_values = multiple_value_columns
      seen
    end
  end
end
