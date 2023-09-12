# fill the new column name. Functions are written to the file in the order in which these are defined
# e.g. Operation Date is the first column in the new csv file
fill_column "Date" do |row|
  row.operation_date
end

fill_column "Type" do |row|
  row.operation_type
end

fill_column "Received Asset" do |row|
  if row.countervalue_at_operation_date && row.countervalue_at_csv_export
    row.countervalue_at_operation_date + row.countervalue_at_csv_export
  end
  nil
end
