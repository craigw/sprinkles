module Sprinkles
  module Processor
    class Greeter
      def call(bot, origin, command, room)
        if command =~ /^JOIN$/ && !(origin.nickname == bot.nickname)
          bot.say room, "Hi #{origin}"
        end
      end
    end
  end
end