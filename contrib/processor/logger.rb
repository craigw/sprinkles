module Sprinkles
  module Processor
    class Logger
      def call(bot, origin, command, parameters)
        if command =~ /^PRIVMSG (\#+[a-zA-Z0-9\_\-\.]+)$/
          room = command.scan(/^PRIVMSG (\#+[a-zA-Z0-9\_\-\.]+)$/)[0]
          File.open("#{room}-#{Time.now.strftime("%Y-%m-%d")}.log", "a+") do |f|
            f.puts("[#{Time.now}] #{origin.nickname}> #{parameters}")
            f.flush
          end
        end
      end
    end
  end
end