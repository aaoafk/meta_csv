# frozen_string_literal: true

require_relative 'bazooka_base'

module Bazooka
  # `Transaction` is really just a single data point
  class Transaction
    include BazookaBase

    LedgerTransaction = Data.define(*LEDGER_LIVE_CSV_ROW_HEADERS.values)
    CoinTrackerTransaction = Data.define(*COIN_TRACKER_CSV_ROW_HEADERS.values)
    TurboTaxTransaction = Data.define(*TURBO_TAX_CSV_ROW_HEADERS.values)
  end
end
