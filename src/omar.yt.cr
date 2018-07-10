require "./omar.yt/*"
require "kemal"
require "syntax"
require "xml"
require "html"

macro rendered(filename)
  render "src/omar.yt/views/#{{{filename}}}"
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

posts = {} of String => {name: String, content: String}
paths = Dir.children("./src/omar.yt/posts/").sort_by { |file| File.info("./src/omar.yt/posts/#{file}").modification_time }.reverse
paths.each do |post|
  name = post.rstrip(".md")

  content = File.read("./src/omar.yt/posts/#{post}")
  content = String.build do |io|
    renderer = CustomRenderer.new(io, meta_grammar)
    Markdown.parse(content, renderer)
  end

  posts[name.downcase.gsub(" ", "-")] = {name: name, content: content}
end

get "/syntax/demo" do |env|
  grammar = highlighter.highlight(default_grammar, meta_grammar)
  input = highlighter.highlight(default_input, default_grammar)

  rendered "syntax.ecr"
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

head = <<-END_HEAD
<head>
<style>
body {
  margin: 40px auto;
  max-width: 650px;
  padding: 0 10px;
  font-family: Open Sans,Arial;
  color: #454545;
  line-height: 1.2;
}

code {
  background: #f8f8f8;
}

a {
  color: #0366d6;
  text-decoration: none;
}

pre code {
  overflow: auto;
  tab-size: 4;
  display: block;
  padding: 0.5em;
}
</style>
</head>
END_HEAD

get "/" do |env|
  content = head
  content += "<body>"
  posts.each do |key, value|
    content += %(<h1><a href="#{key}">#{value[:name]}</a></h1>)
    content += value[:content]
    if key != posts.last_key?
      content += %(<hr style="margin-left:1em; margin-right:1em;">)
    end
  end
  content += "</body>"
  content
end

get "/:path" do |env|
  path = env.params.url["path"]
  name = path.downcase.gsub(" ", "-")

  if posts[name]?
    post = posts[name]

    head + <<-END_BODY
    <body>
      <h1>#{post[:name]}</h1>
      #{post[:content]}
    </body>
    END_BODY
  else
    env.redirect "/"
  end
end

Kemal.run
