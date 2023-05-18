# fill the new column name. Functions are written to the file in the order in which these are defined
# e.g. Operation Date is the first column in the new csv file
fill_column 'Date' do |transaction|
  puts transaction.operation_date
  op_date = Time.parse transaction.operation_date
  op_date.strftime '%Y-%m-%d %H:%M:%S'
end

# fill 2, "Type", "type" do |transaction|
#   'OTHER'
# end

# fill 3, "asset", "sent_asset" do |transaction|
#   t.currency_ticker
# end

# fill "received_asset" do |t|
#   return nil unless t.operation_type == 'IN'

#   t.operation_amount
# end

# fill "fee_asset" do |t|
#   t.currency_ticker
# end

# fill "fee_amount" do |t|
#   t.operation_fees
# end

# fill "market_value" do |t|
#   t.countervalue_at_csv_export
# end

# fill "description" do |t|
#   ''
# end

# fill "transaction_hash" do |t|
#   t.operation_hash
# end

# fill "transaction_id" do |t|
#   ''
# end
