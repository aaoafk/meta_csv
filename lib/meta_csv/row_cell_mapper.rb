# frozen_string_literal: true

require_relative "meta_csv_base"
require_relative "transaction"

module MetaCsv
  class RowCellMapper # :nodoc:
    include MetaCsvBase
    attr_accessor :meta_csv
    attr_reader :curr_row, :standardizer

    def initialize(standardizer)
      @standardizer = standardizer
      x = Data.define(*standardizer.old_headers.each(&:to_sym))
      RowCellMapper.const_set(:InferredRow, x)
    end

    def curr_row=(curr_csv_row)
      @curr_row = initialize_inferred_row curr_csv_row
    end

    def standardize_row
      #########################################################################################################################
      # If the validator infers then everything is given .maybe how can we guard nil access with transformation functions?    #
      #########################################################################################################################
      standardized_row = []
      standardizer.standardizing_functions.each do |st|
        standardized_row << (st.invoke_standardization.call curr_row)
      end
      standardized_row
    end

    private

    def initialize_inferred_row curr_csv_row
      row_data = {}
      standardizer.old_headers.each do |el|
        row_data.fetch(el) { |k| row_data[k] = curr_csv_row[el] }
      end
      InferredRow.new(**row_data)
    end

    def initialize_ledger_transaction curr_csv_row
      Transaction::LedgerTransaction.new(
        operation_date: curr_csv_row[:operation_date],
        currency_ticker: curr_csv_row[:currency_ticker],
        operation_type: curr_csv_row[:operation_type],
        operation_amount: curr_csv_row[:operation_amount],
        operation_fees: curr_csv_row[:operation_fees],
        operation_hash: curr_csv_row[:operation_hash],
        account_name: curr_csv_row[:account_name],
        account_xpub: curr_csv_row[:account_xpub],
        countervalue_ticker: curr_csv_row[:countervalue_ticker],
        countervalue_at_operation_date: curr_csv_row[:countervalue_at_operation_date],
        countervalue_at_csv_export: curr_csv_row[:countervalue_at_csv_export]
      )
    end

    ###########################################################################
    #    All of these could hook into the initialize inferred row method...   #
    ###########################################################################
    def initialize_coin_tracker_transaction curr_csv_row
      Transaction::CoinTrackerTransaction.new
    end

    def initialize_turbo_tax_transaction curr_csv_row
      Transaction::TurboTaxTransaction.new
    end
  end
end
