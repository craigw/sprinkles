require 'thread'
module Sprinkles
  module Processor
    class Logger
      attr_reader :directory, :log_pattern, :messages

      def initialize(log_pattern = "%Y%m%d.log", directory = Dir.pwd)
        @semaphore = Mutex.new
        @log_pattern = log_pattern
        @directory = directory
        @messages = []
        @logthread = Thread.new(@semaphore, self) do |semaphore, bot|
          loop do
            queue = bot.messages
            if queue.any?
              semaphore.synchronize {
                messages = []
                while message = queue.shift
                  messages << message
                end
                bot.log { |file|
                  messages.each { |message| file.puts(message) }
                }
              }
            end
            sleep 60
          end
        end
      end

      def call(bot, origin, command, parameters)
        if command =~ /^PRIVMSG (\#+[a-zA-Z0-9\_\-\.]+)$/
          @semaphore.synchronize {
            @messages << "#{timestamp} #{bot.server[:hostname]} #{origin} #{command} #{parameters}"
          }
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

      def logfile
        File.join(directory, "#{Time.now.strftime(log_pattern)}")
      end

      def log(&block)
        # TODO: I should really hold the file open until it's time to rotate.
        File.open(logfile, "a+") { |f| yield f }
      end
    end
  end
end