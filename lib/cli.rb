require 'thor'
require_relative 'meta_csv'

class MetaCsvCLI < Thor
  package_name "meta_csv"
  map '-L' => :list
  # HACK: Implement CLI

  # Public methods become commands
  # We can describe method usage with desc "cmd_name param", "friendly description of the action"
  desc "transform_csv file_path transformations schema_file_path", "transform csv"
  def transform_csv(file_path, transformations, schema_file_path = nil)
    raise "provided file path does not exist" unless File.exist? file_path

    unless schema_file_path.nil?
      raise "provided validation schema does not exist" if !File.exist?(schema_file_path)
    end

    MetaCsv::Manager.run(file_path:, transformations:, schema_file_path:)
  end
end

MetaCsvCLI.start ARGV
