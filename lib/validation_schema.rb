validation_schema do
  require 'dry/schema'
  Dry::Schema.Params do
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
end
