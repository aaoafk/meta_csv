# frozen_string_literal: true

# TODO: Zeitwerkify and replace `parallel` with `async`

module MetaCsv # :nodoc:
  require 'amazing_print'
  require 'parallel'
  require_relative 'meta_csv/manager'
  require_relative 'meta_csv/version'
  require_relative 'meta_csv/meta_csv_base'
  require_relative 'meta_csv/file_chunker'
  require_relative 'meta_csv/transformer'
  require_relative 'meta_csv/csv_data_manipulator'
  require_relative 'meta_csv/valcoerc'
  require_relative 'meta_csv/schema_builder'
end
