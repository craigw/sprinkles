module Sprinkles
  class Origin
    attr_accessor :prefix

    def initialize(prefix)
      @prefix = prefix
    end

    def nickname
      @prefix.to_s.split(/!/, 2)[0]
    end

    def to_s
      case
      when nickname != ""
        nickname
      when @prefix
        @prefix
      else
        "-unknown-"
      end
    end
  end
end