# frozen_string_literal: true

# REVIEW: Possibility of implementing with Rover?
module MetaCsv
  class CSVDataManipulator # :nodoc:

    # TODO: Implement a set of valid operations on a csv that's a crypto tax format
    def initialize(csv:)
      raise InvalidDataObjectError unless csv.is_a? CSV

      @data = csv
    end

    class CSVDataManipulator < StandardError; end
    class InvalidDataObjectError < CSVDataManipulator; end
  end
end
