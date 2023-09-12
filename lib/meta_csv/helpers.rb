# frozen_string_literal: true

# REVIEW: This is really only a File Accessor utility class
module MetaCsv
  module Helpers
    class << self
      def read_file
        filesystem_access(file, :read) do
          File.open(file, "r:UTF-8", &:read)
        end
      end

      def filesystem_access(path, action = :write, &block)
        yield(path.dup.tap { |x| x.untaint if RUBY_VERSION < "2.7" })
      rescue Errno::EACCES
        warn
      rescue Errno::EAGAIN
        warn
      rescue Errno::EPROTO
        warn
      rescue Errno::ENOSPC
        warn
      rescue *[const_get_safely(:ENOTSUP, Errno)].compact
        warn
      rescue Errno::EEXIST, Errno::ENOENT
        warn
      rescue SystemCallError => e
        raise
      end
    end

    class HelperError < StandardError; end

    class HelperFilePermissionsError < HelperError
      def initialize(path, permission_type = :write)
        @path = path
        @permission_type = permission_type
      end

      def action
        case @permission_type
        when :read then "read from"
        when :write then "write to"
        when :executable, :exec then "execute"
        else @permission_type.to_s
        end
      end

      def message
        "There was an error while trying to #{action} `#{path}`." \
        "It is likely that you need to grant #{@permission_type} permissions " \
        "for that path."
      end
    end

    def underscore word
      x = /(?=a)b/
      r = /(?:(?<=([A-Za-z\d]))|\b)(#{x})(?=\b|[^a-z])/
      word.gsub!(r) { "#{$1 && "_"}#{$2.downcase}" }
      word.gsub!(/([A-Z])(?=[A-Z][a-z])|([a-z\d])(?=[A-Z])/) { ($1 || $2) << "_" }
      word.tr!("-", "_")
      word.tr! " ", "_"
      word.downcase!
      word
    end
  end
end
