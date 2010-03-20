module Sprinkles
  module Processor
    class Logger
      attr_reader :directory, :log_pattern

      def initialize(log_pattern = "%Y%m%d.log", directory = Dir.pwd)
        @log_pattern = log_pattern
        @directory = directory
      end

      def call(bot, origin, command, parameters)
        if command =~ /^PRIVMSG (\#+[a-zA-Z0-9\_\-\.]+)$/
          room = command.scan(/^PRIVMSG (\#+[a-zA-Z0-9\_\-\.]+)$/)[0][0]
          logfile { |log| log.puts(message) }
        end
      end

      def timestamp
        # TAI64 is 34 seconds ahead of UTC due to leap-seconds and initial 10
        # second difference in 1972.
        fuzz = 34
        now = Time.now.utc
        seconds = now.to_i
        nanoseconds = now.to_f - seconds
        "@40000000%08x%08x" % [ seconds + fuzz, nanoseconds ]
      end

      def logfile(&block)
        filename = File.join(directory, "#{Time.now.strftime(log_pattern)}")
        # TODO: I should really hold the file open until it's time to rotate.
        File.open(logfile, "a+") { |f| f.sync = true; yield f }
      end
    end
  end
end