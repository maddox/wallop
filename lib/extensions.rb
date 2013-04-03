class ::Logger
  alias_method :write, :<<
end

module TOML
  class Transformer < ::Parslet::Transform
    # Utility to properly handle escape sequences in parsed string.
    def self.parse_string(val)
      e = val.length
      s = 0
      o = []
      while s < e
        if val[s].chr == "\\"
          s += 1
          case val[s].chr
          when "t"
            o << "\t"
          when "n"
            o << "\n"
          when "\\"
            o << "\\"
          when '"'
            o << '"'
          when "r"
            o << "\r"
          when "0"
            o << "\0"
          else
            raise "Unexpected escape character: '\\#{val[s]}'"
          end
        else
          o << val[s].chr
        end
        s += 1
      end
      o.join
    end
  end
end
