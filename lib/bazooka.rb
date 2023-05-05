# frozen_string_literal: true

require 'amazing_print'
require_relative 'bazooka/version'
require_relative 'bazooka/bazooka_base'
require_relative 'bazooka/transaction'
require_relative 'bazooka/parser'
require_relative 'bazooka/transformer'
require_relative 'bazooka/csv_data_manipulator'
require_relative 'bazooka/standardizer'

module Bazooka # :nodoc:
  # Read contents from file
  f = File.open("/home/sf/Documents/ledgerlive-operations-2023.03.17.csv", "r")
  csv_file_to_string = f.read

  f.close

  result = Bazooka::Parser.new.call (csv_file_to_string)

  # TODO: Write standard definition

  fill_date = lambda { |t|
    op_date = Time.parse t.operation_date
    op_date.strftime '%Y-%m-%d %H:%M:%S'
  }

  fill_type = lambda { |t|
    'OTHER'
  }

  fill_sent_asset = lambda { |t|
    t.currency_ticker
  }

  fill_received_asset = lambda { |t|
    return nil unless t.operation_type == 'IN'

    t.operation_amount
  }

  fill_fee_asset = lambda { |t|
    t.currency_ticker
  }

  fill_fee_amount = lambda { |t|
    t.operation_fees
  }

  fill_market_value = lambda { |t|
    t.countervalue_at_csv_export
  }

  fill_description = lambda { |t|
    ''
  }

  fill_transaction_hash = lambda { |t|
    t.operation_hash
  }

  fill_transaction_id = lambda { |t|
    ''
  }

  # Turbo Tax Translation Order
  # Date,
  # Type,
  # Sent Asset,
  # Received Asset,
  # Received Amount,
  # Fee Asset,
  # Fee Amount,
  # Market Value,
  # Description,
  # Transaction Hash,
  # Transaction ID

  definition = {
    'Date' => fill_date,
    'Type' => fill_type,
    'Sent Asset' => fill_sent_asset,
    'Received Asset' => fill_received_asset,
    'Fee Asset' => fill_fee_asset,
    'Fee Amount' => fill_fee_amount,
    'Market Value' => fill_market_value,
    'Description' => fill_description,
    'Transaction Hash' => fill_transaction_hash,
    'Transaction ID' => fill_transaction_id
  }

  Bazooka::Transformer.new(
    csv: result,
    from_source: BazookaBase::LEDGER_LIVE_CSV_SOURCE,
    to_source: BazookaBase::TURBO_TAX_CSV_SOURCE,
    standard_definition: definition
  ).transformed_csv

  end
end
