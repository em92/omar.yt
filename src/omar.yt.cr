# "omar.yt" (which is a blog)
# Copyright (C) 2018  Omar Roth
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "html"
require "json"
require "kemal"
require "syntax"
require "xml"
require "./omar.yt/*"

# Helpers

macro rendered(filename)
  render "src/omar.yt/views/#{{{filename}}}.ecr"
end

macro templated(filename)
  render "src/omar.yt/views/#{{{filename}}}.ecr", "src/omar.yt/views/template.ecr"
end

alias Post = NamedTuple(name: String, title: String, author: String, published: Time, content: String)

DOMAIN = "https://omar.yt"
AUTHOR = "Omar Roth"
EMAIL  = "omarroth@hotmail.com"

highlighter = Syntax::Highlighter.new

default_grammar = File.read("./src/omar.yt/grammars/default_grammar.bnf")
meta_grammar = File.read("./src/omar.yt/grammars/meta_grammar.bnf")

marker = <<-'END_BNF'
:discard ~ <this helps the parser know where in the original input markers should be placed>
<this helps the parser know where in the original input markers should be placed> ~ [\x{feff}]
END_BNF

default_input = "10 + (6 - 1 / 3) * 2"
meta_grammar = highlighter.compile(meta_grammar + marker)

# Setup

Kemal::CLI.new

posts = [] of Post
Dir.children("./src/omar.yt/posts/").each do |path|
  post = File.read("./src/omar.yt/posts/#{path}")
  metadata, content = post.split("<<<<<<<")

  title = path.rstrip(".md")
  published = Time.now
  author = AUTHOR

  metadata.split("\n").select { |a| !a.empty? }.each do |tag|
    key, value = tag.split(": ")

    case key
    when "author"
      author = value
    when "published"
      published = Time.parse_rfc2822(value)
    when "title"
      title = value
    else
      puts "Unrecognized key #{key}"
    end
  end

  title ||= path.rchop(".md")
  published ||= Time.now

  content = String.build do |io|
    renderer = CustomRenderer.new(io, meta_grammar)
    Markdown.parse(content, renderer)
  end

  name = title.downcase.gsub(" ", "-")

  posts << {name: name, title: title, author: author, published: published, content: content}
end

posts.sort_by! { |post| post[:published].epoch }
posts.reverse!

# Views

get "/posts.json" do |env|
  env.response.content_type = "application/json"
  posts.to_pretty_json
end

get "/atom.xml" do |env|
  env.response.content_type = "application/atom+xml"

  XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", xmlns: "http://www.w3.org/2005/Atom", "xml:lang": "en-US") do
      xml.element("link", rel: "self", href: "#{DOMAIN}/atom.xml")
      xml.element("title") { xml.text AUTHOR }
      xml.element("author") do
        xml.element("name") { xml.text AUTHOR }
        xml.element("email") { xml.text EMAIL }
        xml.element("uri") { xml.text "#{DOMAIN}/" }
      end
      xml.element("id") { xml.text "#{DOMAIN}/" }

      posts.each do |post|
        xml.element("entry") do
          xml.element("id") { xml.text "#{DOMAIN}/#{post[:name]}" }
          xml.element("title") { xml.text post[:title] }
          xml.element("updated") { xml.text post[:published].to_s }
          xml.element("published") { xml.text post[:published].to_s }
          xml.element("author") do
            xml.element("name") { xml.text AUTHOR }
            xml.element("email") { xml.text EMAIL }
            xml.element("uri") { xml.text "#{DOMAIN}/" }
          end

          xml.element("content", type: "html") { xml.text post[:content] }
        end
      end
    end
  end
end

get "/" do |env|
  templated "index"
end

get "/:name" do |env|
  name = env.params.url["name"]

  if post = posts.select { |post| post[:name] == name }[0]?
    templated "post"
  else
    env.redirect "/"
  end
end

get "/favicon.ico" do |env|
  halt env, status_code: 404
end

# Syntax demo

get "/syntax/demo" do |env|
  grammar = highlighter.highlight(default_grammar, meta_grammar)
  input = highlighter.highlight(default_input, default_grammar)

  rendered "syntax"
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

  input_selection_boundaries = input.xpath_nodes(%q(//span[@class="rangySelectionBoundary"]))
  grammar_selection_boundaries = grammar.xpath_nodes(%q(//span[@class="rangySelectionBoundary"]))

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

    if input_selection_boundaries.size >= i
      input_selection_boundaries[i - 1]
    else
      ""
    end
  end

  i = 0
  grammar = grammar.sub("\ufeff") do |replacement|
    i += 1

    if grammar_selection_boundaries.size >= i
      grammar_selection_boundaries[i - 1]
    else
      ""
    end
  end

  env.response.content_type = "application/json"
  {"input" => input, "grammar" => grammar}.to_json
end

error 404 do |env|
end

# Add redirect if SSL is enabled
if Kemal.config.ssl
  spawn do
    server = HTTP::Server.new do |context|
      redirect_url = "https://#{context.request.host}#{context.request.path}"
      if context.request.query
        redirect_url += "?#{context.request.query}"
      end
      context.response.headers.add("Location", redirect_url)
      context.response.status_code = 301
    end

    server.bind_tcp "0.0.0.0", 80
    server.listen
  end

  before_all do |env|
    env.response.headers.add("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload")
  end
end

static_headers do |response, filepath, filestat|
  response.headers.add("Cache-Control", "max-age=86400")
end

gzip true
public_folder "assets"

Kemal.run
