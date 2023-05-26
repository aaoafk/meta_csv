# frozen_string_literal: true

module Inferencer
  DATE_FORMATS = {
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
  }.freeze

  # A cell responds to header and value
  def infer_types_for_csv_row cells
    inferred_types_for_headers = {}
    cells.each do |cell|
      if /[-+]?[0-9]*\.?[0-9]+/ =~ cell.value
        inferred_types_for_headers[cell.header] = Float
      elsif /^\d+$/ =~ cell.value
        inferred_types_for_headers[cell.header] = Integer 
      elsif matches_date_format? cell.value
        inferred_types_for_headers[cell.header] = Date 
      else
        inferred_types_for_headers[cell.header] = String
      end
    end

    # Just return val
    inferred_types_for_headers
  end

  private

  def matches_date_format? val
    DATE_FORMATS.each do |_, v|
      Date.strptime(val, v) rescue next
      return v
    end
    nil
  end
end
