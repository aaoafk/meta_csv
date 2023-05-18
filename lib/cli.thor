require 'thor'

class BazookaRun < Thor
  
  # HACK :: Implement CLI

  # Public methods become commands
  # We can describe method usage with desc "cmd_name param", "friendly description of the action"
  desc "transform_to_csv SOURCE HEADERS FUNCTIONS", "transform to csv"
  def transform_to_csv

  end
end

BazookaRun.start ARGV
