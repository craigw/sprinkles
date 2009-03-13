module Sprinkles
  module Processor
    class Ping
      def call(bot, origin, command, parameters)
        if command =~ /^PING$/
          bot.send_message("PONG :#{parameters}")
        end
      end
    end
  end
end