require "./omar.yt/*"
require "kemal"
require "syntax"
require "xml"
require "html"

macro templated(filename)
  render "src/omar.yt/#{{{filename}}}"
end

highlighter = Syntax::Highlighter.new

default_grammar = <<-'END_BNF'
# Grammar from https://metacpan.org/pod/distribution/Marpa-R2/pod/Semantics.pod
:start ::= Expression
Expression ::= Number
| '(' Expression ')' bgcolor => salmon
|| Expression '**' Expression bgcolor => red
|| Expression '*' Expression bgcolor => yellow color => black
| Expression '/' Expression bgcolor => green color => orange
|| Expression '+' Expression bgcolor => blue color => orange
| Expression '-' Expression bgcolor => cyan color => black

Number ~ [\d]+

:discard ~ whitespace
whitespace ~ [\s]+
END_BNF

meta_grammar = <<-'END_BNF'
:start ::= statements
statements ::= statement+
statement ::= <start rule> color => red
  | <priority rule> color => green
  | <quantified rule> color => blue
  | <discard rule> color => gray
  | <empty rule> color => gray

<start rule> ::= ':start' <op declare bnf> <single symbol>
<priority rule> ::= lhs <op declare> priorities
<quantified rule> ::= lhs <op declare> <single symbol> quantifier <adverb list>
<discard rule> ::= ':discard' <op declare match> <single symbol>
<empty rule> ::= lhs <op declare> <adverb list>

priorities ::= alternatives+
    separator => '||' proper => 1
alternatives ::= alternative+    
    separator => '|' proper => 1
alternative ::= rhs <adverb list> bgcolor => snow

<adverb list> ::= <adverb item>* color => cadetblue
<adverb item> ::= <separator specification>
  | <proper specification>
  | <rank specification>
  | <color specification>
  | <bgcolor specification>

<separator specification> ::= 'separator' '=>' <single symbol>
  | 'separator' '=>' <single quoted string>
<proper specification> ::= 'proper' '=>' boolean
<rank specification> ::= 'rank' '=>' digit
<color specification> ::= 'color' '=>' color 
<bgcolor specification> ::= 'bgcolor' '=>' color 

color ::= <hex color>
  | <css color>
<hex color> ~ /#[a-fA-F0-9]{6}/
<css color> ~ [\w]+

lhs ::= symbol
rhs ::= <rhs primary>+
<rhs primary> ::= <single symbol>
  | <single quoted string>
  | <parenthesized rhs primary list>
<parenthesized rhs primary list> ::= '(' <rhs list> ')'
<rhs list> ::= <rhs primary>+

<single symbol> ::= symbol
  | <character class> color => turquoise
  | <regex> color => turquoise
symbol ::= <symbol name>
<symbol name> ::= <bare name>
  | <bracketed name>

:discard ~ whitespace
whitespace ~ [\s]+

<op declare> ::= <op declare bnf> | <op declare match>

<op declare bnf> ~ '::='
<op declare match> ~ '~'
quantifier ::= '*' | '+'

<name> ~ [\w]+
boolean ~ [01]
digit ~ [\d]+
<before or after> ::= 'before' | 'after'

<bare name> ~ [\w]+
<bracketed name> ~ '<' <bracketed name string> '>'
<bracketed name string> ~ [\s\w]+

<single quoted string> ::= <quoted string> color => peru
<quoted string> ~ /'[^'\x0A\x0B\x0C\x0D\x{0085}\x{2028}\x{2029}]+'/

<regex> ~ /\/.*\/[imx]{0,3}/
<character class> ~ '[' <cc elements> ']'
<cc elements> ~ [^\x5d\x0A\x0B\x0C\x0D\x{0085}\x{2028}\x{2029}]+

# Allow comments
:discard ~ <hash comment>
<hash comment> ~ /#[^\n]*/
END_BNF

marker = <<-'END_BNF'
:discard ~ <this helps the parser know where in the original input markers should be placed>
<this helps the parser know where in the original input markers should be placed> ~ [\x{feff}]
END_BNF

default_input = "10 + (6 - 1 / 3) * 2"
meta_grammar = highlighter.compile(meta_grammar + marker)

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

  marked = :grammar
  rangySelectionBoundaries = grammar.xpath_nodes(%q(//span[@class="rangySelectionBoundary"]))
  if rangySelectionBoundaries.empty?
    marked = :input
    rangySelectionBoundaries = input.xpath_nodes(%q(//span[@class="rangySelectionBoundary"]))
  end

  input = input.content
  grammar = grammar.content

  begin
    input = highlighter.highlight(input, grammar.delete('\ufeff') + marker)
    grammar = highlighter.highlight(grammar, meta_grammar)
  rescue ex
    next {"error" => ex.message}.to_json
  end

  if marked == :input
    i = 0
    input = input.sub("\ufeff") do |replacement|
      i += 1
      rangySelectionBoundaries[i - 1]
    end
  else
    i = 0
    grammar = grammar.sub("\ufeff") do |replacement|
      i += 1
      rangySelectionBoundaries[i - 1]
    end
  end

  env.response.content_type = "application/json"
  {"input" => input, "grammar" => grammar}.to_json
end

error 404 do |env|
  env.response.status_code = 301
  next env.redirect "/"
end

Kemal.run
