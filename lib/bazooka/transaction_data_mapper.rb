# frozen_string_literal: true

require_relative 'bazooka_base'
require_relative 'transaction'

module Bazooka
  class TransactionDataMapper # :nodoc:
    include BazookaBase
    attr_accessor :transaction, :meta_csv
    attr_reader :standardizer

    def initialize(meta_csv)
      @meta_csv = meta_csv
      @standardizer = Standardizer.instance
      x = Data.define(*meta_csv.old_headers.each(&:to_sym))
      TransactionDataMapper.const_set('GeneralTransaction', x)
    end

    def transaction=(curr_csv_row)
      case meta_csv.source
      when LEDGER_LIVE_CSV_SOURCE
        @transaction = initialize_ledger_transaction curr_csv_row
      when COIN_TRACKER_CSV_SOURCE
        @transaction = initialize_general_transaction curr_csv_row
      when TURBO_TAX_CSV_SOURCE
        @transaction = initialize_general_transaction curr_csv_row
      else
        @transaction = initialize_general_transaction curr_csv_row
      end
    end

    def standardize_transaction
      standardized_row = []
      puts
      standardizer.standardizing_functions.each do |st|
        standardized_row << (st.invoke_standardization.call transaction)
      end
      standardized_row
    end

    private

    def initialize_general_transaction curr_csv_row
      trans_hsh = {}
      standardizer.old_headers.each do |el|
        trans_hsh.fetch(el) { |k| trans_hsh[k] = curr_csv_row[el] }
      end
      GeneralTransaction.new(**trans_hsh)
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


    # TODO: All of these just hook into initialize_general_transaction
    def initialize_coin_tracker_transaction curr_csv_row
      Transaction::CoinTrackerTransaction.new
    end

    # TODO: Implement with headers
    def initialize_turbo_tax_transaction curr_csv_row
      Transaction::TurboTaxTransaction.new
    end

  end
end
