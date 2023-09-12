# frozen_string_literal: true

require_relative "meta_csv_base"

module MetaCsv
  # `Transaction` is really just a single data point
  class Transaction
    include MetaCsvBase

    LedgerTransaction = Data.define(*LEDGER_LIVE_CSV_ROW_HEADERS.values)
    CoinTrackerTransaction = Data.define(*COIN_TRACKER_CSV_ROW_HEADERS.values)
    TurboTaxTransaction = Data.define(*TURBO_TAX_CSV_ROW_HEADERS.values)
  end
end
