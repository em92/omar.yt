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
require "instagram"
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

alias Post = NamedTuple(name: String, title: String, author: String, published: Time, updated: Time, content: String)

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

# Kemal::CLI.new

posts = [] of Post
Dir.children("./src/omar.yt/posts/").each do |path|
  post = File.read("./src/omar.yt/posts/#{path}")
  metadata, content = post.split("<<<<<<<")

  author = nil
  published = nil
  title = nil
  updated = nil

  metadata.split("\n").select { |a| !a.empty? }.each do |tag|
    key, value = tag.split(": ")

    case key
    when "author"
      author = value
    when "published"
      published = Time.parse_rfc2822(value)
    when "title"
      title = value
    when "updated"
      updated = Time.parse_rfc2822(value)
    else
      puts "Unrecognized key #{key}"
    end
  end

  author ||= AUTHOR
  published ||= Time.now
  title ||= path.rchop(".md")
  updated ||= published

  content = String.build do |io|
    renderer = CustomRenderer.new(io, meta_grammar)
    Markdown.parse(content, renderer)
  end

  name = title.downcase.gsub(" ", "-")

  posts << {name: name, title: title, author: author, published: published, updated: updated, content: content}
end

posts.sort_by! { |post| post[:published].to_unix }
posts.reverse!

# Views

get "/posts.json" do |env|
  env.response.content_type = "application/json"
  posts.to_pretty_json
end

get "/instagram/rss/:username" do |env|
  env.response.content_type = "application/atom+xml"

  username = env.params.url["username"]

  user_info = Instagram.get_user_page(username)
  user_id = user_info["id"].as_s
  full_name = user_info["full_name"].as_s

  XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", xmlns: "http://www.w3.org/2005/Atom", "xml:lang": "en-US") do
      xml.element("link", rel: "self", href: "#{DOMAIN}/instagram/rss/#{username}")
      xml.element("title") { xml.text "Instagram Feed for #{full_name}" }
      xml.element("author") do
        xml.element("name") { xml.text full_name }
        xml.element("uri") { xml.text "https://www.instagram.com/#{username}/" }
      end
      xml.element("id") { xml.text user_id }

      nodes = user_info["edge_owner_to_timeline_media"]["edges"].as_a
      nodes.each do |node|
        node = node["node"]

        id = node["id"].as_s

        title = node["edge_media_to_caption"]["edges"][0]?.try &.["node"]["text"].as_s
        title ||= ""

        published = node["taken_at_timestamp"].as_i
        published = Time.unix(published).to_s

        image_url = node["display_url"].as_s

        content = <<-END_HTML
        <h3>#{title}</h3>
        <img src="#{image_url}"/>
        END_HTML

        xml.element("entry") do
          xml.element("id") { xml.text id }
          xml.element("title") { xml.text title }
          xml.element("published") { xml.text published }
          xml.element("author") do
            xml.element("name") { xml.text full_name }
            xml.element("uri") { xml.text "https://www.instagram.com/#{username}/" }
          end

          xml.element("content", type: "html") { xml.text content }
        end
      end
    end
  end
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
          xml.element("updated") { xml.text post[:updated].to_s }
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
