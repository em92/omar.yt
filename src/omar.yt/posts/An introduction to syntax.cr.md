title: An introduction to syntax.cr
published: Mon, 9 Jul 2018 23:04:15 -0500
author: Omar Roth
<<<<<<<

## Introduction

The [.tmLanguage format](https://manual.macromates.com/en/language_grammars) is currently the most popular tool for adding syntax highlighting to popular editors. It is supported by Github, VSCode, Atom, Vim, TextMate (after which it is named), and many others.

However, it is extremely limited in its ability to actually **understand** the language the user hopes to use (packages are often limited to naive keyword highlighting) which often leads to a misleading or unexpected result. In order for an editor to provide useful information to the user, it is necessary for the editor to properly parse the given input.

With that in mind, here is a short introduction to [syntax.cr](https://github.com/omarroth/syntax.cr).

## Description of a language

People familiar with the original Perl library's [Scanless Interface](https://metacpan.org/pod/distribution/Marpa-R2/pod/Scanless/DSL.pod) can skip this section, and go straight to [colorizing the given grammar](#colorizing-a-grammar).

The language used to describe grammars is an extended form of [EBNF](https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form#Basics). Each rule in a language can be described as:

```ebnf
S ::= a b c
```

Sequences (highlighted in `blue`) can be expressed in the form:

```ebnf
# Zero or more
S ::= a*

# One or more
S ::= a+
```

And alternations (highlighted in `green`) can be expressed as:

```ebnf
S ::= a | b
```

Each rule can have associated `adverbs` (highlighted in `cadetblue`), which provide extra meaning that cannot be captured in pure EBNF. For example:

```ebnf
S ::= a* separator => comma
```

This specifices a sequence of 0 or more `a` separated by commas.

At this point it is helpful to provide a simple grammar as an example. Here is one of JSON:

```ebnf
# Adapted from https://gist.github.com/pstuifzand/4447349
:start ::= json
json ::= object | array

object ::= '{' members '}'
members ::= pair* proper => 1 separator => comma
pair ::= string ':' value

value ::= string
  | object
  | number
  | array
  | true
  | false
  | null

array ::= '[' elements ']'
elements ::= value* proper => 1 separator => comma

comma ~ ','

string ::= '"' in_string '"'
in_string ~ /([^"\\]|\\[\"\\\/bftnrt]|\\u[a-fA-F0-9]{4})*/
number ~ /-?([\d]+)(\.\d+)?([eE][+-]?\d+)?/

true ~ 'true'
false ~ 'false'
null ~ 'null'

:discard ~ whitespace
whitespace ~ [\s]+
```

There is a clear distinction between `~` and `::=`. Rules that have a `~` are called L0 rules. They define tokens, and can **not** have adverbs assigned directly to them. Rules that have a `::=` are called G1 rules and define the structure of the language. For more information see [the Marpa FAQ](http://savage.net.au/Perl-modules/html/marpa.faq/faq.html#q109).

The `proper` adverb specifies whether or not there can be a trailing separator.

The rest of the above constructs should be fairly self-explanatory, however I would recommend playing with the [demo](/syntax/demo) to better explore how it works. You can edit the grammar on the left and the input on the right to colorize your given language.

To implement precedence and associativity (for example in a calculator), the `||` operator can be used in rules, like so:

```ebnf
Expression ::= Number
  | Expression '*' Expression
 || Expression '+' Expression
```

The [documentation on metacpan.org](https://metacpan.org/pod/distribution/Marpa-R2/pod/Scanless/DSL.pod) provides more information.

## Colorizing a grammar

So now we have a grammar described in EBNF, how do we use that to highlight our language?

Each rule can be tagged with a `color` and/or `bgcolor` that corresponds to CSS's `color` and `background-color` attributes, respectively. An example rule looks like:

```ebnf
object ::= '{' members '}' bgcolor => blue color => #aaffcc
```

`color` and `bgcolor` can either be one of the [140 colors supported by all browsers](https://www.w3schools.com/colors/colors_names.asp), or a hexadecimal color in the standard `#RRGGBB` format.

Here is our colorized JSON grammar:

```ebnf
# Adapted from https://gist.github.com/pstuifzand/4447349
:start ::= json
json ::= object | array

object ::= '{' members '}' bgcolor => lightgoldenrodyellow
members ::= pair* proper => 1 separator => comma
pair ::= string ':' value

value ::= string
  | object
  | number color => purple
  | array
  | true color => blue
  | false color => blue
  | null color => tomato

array ::= '[' elements ']' bgcolor => lightcyan
elements ::= value* proper => 1 separator => comma

comma ~ ','

string ::= '"' in_string '"' color => peru
in_string ~ /([^"\\]|\\[\"\\\/bftnrt]|\\u[a-fA-F0-9]{4})*/
number ~ /-?([\d]+)(\.\d+)?([eE][+-]?\d+)?/

true ~ 'true'
false ~ 'false'
null ~ 'null'

:discard ~ whitespace
whitespace ~ [\s]+
```

This can be called from Crystal like so:

```crystal
require "syntax"

grammar = <<-'END_EBNF'
<grammar shown above>
END_EBNF

input = %({"a" : 1, "b" : [1,2,3]})

highlighter = Syntax::Highlighter.new
highlighter.highlight(input, grammar)
```

which will produce an HTML document where the input is tagged with the specified colors.

This can be rendered directly, or other actions can be performed to provide useful information to the user.

## Why should I use this?

The given example above hopefully demonstrates how easy it is to describe a desired language and quickly achieve a good-looking result. In addition, the [demo](/syntax/demo) is fast enough to provide feedback in real-time.

The capability of this tool is thanks to [Marpa](http://jeffreykegler.github.io/Marpa-web-site/), which makes it possible to describe potentially ambiguous grammars quickly and easily.

## What's the catch?

There are a significant number of languages that cannot be adequately described using only EBNF. As an example, consider Javascript. In Javascript, semicolons are optional, meaning that a liberal parser must be able to actively invent tokens in order to parse Javascript found in the wild.

The core library, [marpa](https://github.com/omarroth/marpa), does provide tools for handling these kinds of languages, however this functionality is not yet supported in syntax.cr.

## Conclusion

I think [syntax.cr](https://github.com/omarroth/syntax.cr) is likely the easiest way to go from a grammar to a nice-looking highlighter.

All the EBNF samples shown above were colorized using syntax.cr, and the [demo](/syntax/demo) should further show the capability of this tool.

For other applications, I would refer readers to the [marpa library](https://github.com/omarroth/marpa) written in Crystal, or the [original SLIF interface](https://metacpan.org/pod/distribution/Marpa-R2/pod/Semantics.pod), written in Perl.
