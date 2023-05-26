# frozen_string_literal: true

module MetaCsv 
  module MetaCsvBase 
    require 'dry/schema'
    Dry::Schema.load_extensions :monads

    include Dry::Monads[:result]

    LEDGER_LIVE_CSV_SOURCE = :LEDGER_LIVE_CSV_SOURCE
    COIN_TRACKER_CSV_SOURCE = :COIN_TRACKER_CSV_SOURCE
    TURBO_TAX_CSV_SOURCE = :TURBO_TAX_CSV_SOURCE
    OTHER_CSV_SOURCE = :OTHER_CSV_SOURCE
    INFER = :INFER

    ###########################################################################
    #               RESEARCHED CONSTANTS THAT MIGHT BE VALUABLE                #
    ###########################################################################

    TURBO_TAX_DATE_FORMAT = '%Y-%m-%d %H:%M:%S'
    TURBO_TAX_TRANSACTION_TYPES = [
      'Buy',
      'Sale',
      'Convert',
      'Transfer',
      'Income',
      'Interest',
      'Expense',
      'Deposit',
      'Withdrawal',
      'Mining',
      'Airdrop',
      'Forking',
      'Staking',
      'Other'
    ].freeze

    ###########################################################################
    #                    SCHEMAS TO VALIDATE TRANSFORMATION                    #
    ###########################################################################

    require 'refinements/hashes'

    LedgerLiveValidationSchema = Dry::Schema.Params do
      before(:key_coercer) { |result| result.to_h.symbolize_keys! }

      required(:body).array(:hash) do
        required(:operation_date).filled(:date_time)
        required(:currency_ticker).filled(:string)
        required(:operation_type).filled(:string)
        required(:operation_amount).filled(:float)
        required(:operation_fees).filled(:float)
        required(:operation_hash).filled(:string)
        required(:account_name).filled(:string)
        required(:account_xpub).filled(:string)
        required(:countervalue_ticker).filled(:string)
        required(:countervalue_at_operation_date).maybe(:float)
        required(:countervalue_at_csv_export).maybe(:float)
      end
    end

    CoinTrackerValidationSchema = Dry::Schema.Params do
      required(:body).array(:hash) do
        required(:date).filled(:date_time)
        required(:received_quantity).filled(:float)
        required(:received_currency).filled(:string)
        required(:sent_quanity).filled(:float)
        required(:sent_currency).filled(:string)
      end
    end

    TurboTaxValidationSchema = Dry::Schema.Params do
      required(:body).array(:hash) do
        required(:date).filled(:date_time)
        required(:type).filled(:string)
        required(:sent_asset).filled(:string)
        required(:received_asset).filled(:string)
        required(:received_amount).filled(:float)
        required(:fee_asset).maybe(:string)
        required(:fee_amount).maybe(:float)
        required(:market_value).maybe(:string)
        required(:description).maybe(:string)
        required(:transaction_hash).maybe(:string)
        required(:transaction_id).maybe(:string)
      end
    end

    ###########################################################################
    #                           DEFINED CSV HEADERS                           #
    ###########################################################################

    LEDGER_LIVE_CSV_ROW_HEADERS = {
      'operation_date' => :operation_date,
      'currency_ticker' => :currency_ticker,
      'operation_type' => :operation_type,
      'operation_amount' => :operation_amount,
      'operation_fees' => :operation_fees,
      'operation_hash' => :operation_hash,
      'account_name' => :account_name,
      'account_xpub' => :account_xpub,
      'countervalue_ticker' => :countervalue_ticker,
      'countervalue_at_operation_date' => :countervalue_at_operation_date,
      'countervalue_at_csv_export' => :countervalue_at_csv_export
    }.freeze

    COIN_TRACKER_CSV_ROW_HEADERS = {
      'date' => :date,
      'received_quanity' => :received_quanity,
      'received_currency' => :received_currency,
      'sent_quanity' => :sent_quanity,
      'sent_currency' => :sent_currency,
      'fee_amount' => :fee_amount,
      'fee_currency' => :fee_currency,
      'tag' => :tag
    }.freeze

    TURBO_TAX_CSV_ROW_HEADERS = {
      'date' => :date,
      'type' => :type,
      'sent_asset' => :sent_asset,
      'sent_amount' => :sent_amount,
      'received_asset' => :received_asset,
      'received_amount' => :received_amount,
      'fee_asset' => :fee_asset,
      'fee_amount' => :fee_amount,
      'market_value_currency' => :market_value_currency,
      'market_value' => :market_value,
      'description' => :description,
      'transaction_hash' => :transaction_hash,
      'transaction_id' => :transaction_id
    }.freeze

  end
end
