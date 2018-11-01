require "markdown"
require "openssl"

class CustomRenderer < Markdown::HTMLRenderer
  def initialize(@io : IO, @grammar : Syntax::Grammar | String)
    super(io)

    @code_buffer = IO::Memory.new
    @inside_code = false
    @header_buffer = IO::Memory.new
    @inside_header = false
  end

  def begin_code(language)
    super

    case language
    when "ebnf"
      @inside_code = true
      @code_buffer.clear
    end
  end

  def end_code
    if @inside_code
      highlighter = Syntax::Highlighter.new

      text = highlighter.highlight(@code_buffer.to_s, @grammar)
      @io << text
    end

    @inside_code = false

    super
  end

  def begin_header(level)
    super

    @inside_header = true
    @header_buffer.clear
  end

  def end_header(level)
    if @inside_header
      @io << "<h"
      @io << level
      heading_id = @header_buffer.to_s.underscore.gsub(/[#?&_\s]+/, "-")
      @io << " id=\"#{heading_id}\">"
      @io << @header_buffer
      @io << "</h#{level}>"
    end

    @inside_header = false

    super
  end

  def text(text)
    if @inside_code
      @code_buffer << text
      return
    end

    if @inside_header
      @header_buffer << text
      return
    end

    super(text)
  end
end

def sha256(text)
  digest = OpenSSL::Digest.new("SHA256")
  digest << text
  return digest.hexdigest
end
