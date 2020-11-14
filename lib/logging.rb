require 'logger'

# From https://stackoverflow.com/a/23508304
module Logging
  class << self
    def logger
      @logger ||= Logger.new($stdout)
    end

    def logger=(logger)
      @logger = logger
    end
  end

  def self.included(base)
    class << base
      def logger
        Logging.logger
      end
    end
  end

  def logger
    Logging.logger
  end
end