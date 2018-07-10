require "./omar.yt/*"
require "kemal"
require "syntax"
require "xml"
require "html"

macro templated(filename)
  render "src/omar.yt/#{{{filename}}}"
end

highlighter = Syntax::Highlighter.new

default_grammar = File.read("./src/omar.yt/grammars/default_grammar.bnf")
meta_grammar = File.read("./src/omar.yt/grammars/meta_grammar.bnf")

marker = <<-'END_BNF'
:discard ~ <this helps the parser know where in the original input markers should be placed>
<this helps the parser know where in the original input markers should be placed> ~ [\x{feff}]
END_BNF

default_input = "10 + (6 - 1 / 3) * 2"
meta_grammar = highlighter.compile(meta_grammar + marker)

writings = Dir.children("./src/omar.yt/writings/")
posts = {} of String => String
writings.each do |post|
  name = post.rstrip(".md")
  name = name.gsub(" ", "-")
  name = name.downcase

  content = File.read("./src/omar.yt/writings/#{post}")
  content = String.build do |io|
    renderer = CustomRenderer.new(io, meta_grammar)
    Markdown.parse(content, renderer)
  end

  posts[name] = content
end

get "/" do |env|
  "Hello world"
end

get "/syntax/demo" do |env|
  grammar = highlighter.highlight(default_grammar, meta_grammar)
  input = highlighter.highlight(default_input, default_grammar)

  templated "syntax.ecr"
end

post "/syntax/update" do |env|
  body = env.request.body.try &.gets_to_end

  if !body
    next ""
  end

  json = JSON.parse(body)
  input = json["input"]
  grammar = json["grammar"]

  input = input.as_s
  input = input.gsub("<div>", "\n")
  input = input.gsub("</div>", "")
  input = XML.parse_html(input)

  grammar = grammar.as_s
  grammar = grammar.gsub("<div>", "\n")
  grammar = grammar.gsub("</div>", "")
  grammar = XML.parse_html(grammar)

  grammarSelectionBoundaries = grammar.xpath_nodes(%q(//span[@class="rangySelectionBoundary"]))
  inputSelectionBoundaries = input.xpath_nodes(%q(//span[@class="rangySelectionBoundary"]))

  input = input.content
  grammar = grammar.content

  begin
    input = highlighter.highlight(input, grammar.delete('\ufeff') + marker)
    grammar = highlighter.highlight(grammar, meta_grammar)
  rescue ex
    next {"error" => ex.message}.to_json
  end

  i = 0
  input = input.sub("\ufeff") do |replacement|
    i += 1
    inputSelectionBoundaries[i - 1]
  end

  i = 0
  grammar = grammar.sub("\ufeff") do |replacement|
    i += 1
    grammarSelectionBoundaries[i - 1]
  end

  env.response.content_type = "application/json"
  {"input" => input, "grammar" => grammar}.to_json
end

get "/:path" do |env|
  path = env.params.url["path"]
  path = path.downcase

  if posts[path]?
    posts[path]
  else
    env.redirect "/"
  end
end

Kemal.run
