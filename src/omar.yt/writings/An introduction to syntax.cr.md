# An introduction to syntax.cr

## Introduction

The [.tmLanguage format](https://manual.macromates.com/en/language_grammars) is currently the most popular tool for adding syntax highlighting to popular editors. It is supported by Github, VSCode, Atom, Vim, TextMate (after which it is named), and many others.

However, it is extremely limited in its ability to actually **understand** the language the user hopes to use (packages are often limited to naive keyword highlighting) which often leads to misleading or unexpected outcomes. In order for an editor to provide useful information to the user, it is necessary for the editor to properly parse the given input.

With that in mind, here is a short introduction to [syntax.cr](https://github.com/omarroth/syntax.cr)

## Description of a language

People familiar with the original Perl library's [Scanless Interface](https://metacpan.org/pod/distribution/Marpa-R2/pod/Scanless/DSL.pod) can skip this section, and go straight to [colorizing the given grammar](#colorizing-a-grammar).

The language used to describe grammars is an extended form of [EBNF](https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form#Basics). Each rule in a language can be described as:

```ebnf
symbol ::= <symbol a> <symbol b> <symbol c>
```

Sequences can be expressed in the form

```ebnf
# Zero or more
symbol ::= a*

# One or more
symbol ::= a+
```

And alternations can be expressed as:

```ebnf
symbol ::= a | b
```

Each rule can have associated `adverbs`, which provide extra meaning that cannot be captured in pure EBNF.

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
abc ~ 'abc'

:discard ~ whitespace
whitespace ~ [\s]+
```

Most of the constructs above should be fairly self-explanatory, however I would recommend playing with the [demo](/syntax/demo) to better explore how it works.

To implement ambiguity (for example in a calculator), the `||` operator can be used in rules, like so:

```ebnf
Expression ::= Number
  | Expression '*' Expression
  || Expression '*' Expression
```

The [documentation on metacpan.org](https://metacpan.org/pod/distribution/Marpa-R2/pod/Scanless/DSL.pod) provides more information.

## Colorizing a grammar

So now we have a grammar described in BNF, how do we use that to highlight our language?

Each rule can be tagged with a `color` and/or `bgcolor` that corresponds in the output to CSS's `color` and `background-color` attributes, respectively. An example rule looks like:

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
abc ~ 'abc'

:discard ~ whitespace
whitespace ~ [\s]+
```

This can be called from Crystal like so:

```crystal
require "syntax"

grammar = <<-'END_BNF'
<grammar shown above>
END_BNF

input = "example input"
highlighter.highlight(input, grammar)
```

which will produce an HTML document where the input is tagged with the specified colors.

This can be rendered directly, or other actions can be performed to provide useful information to the user.

## Why should I use this?

The given example above hopefully demonstrates how easy it is to describe a desired language and quickly achieve a good-looking result. The [demo](/syntax/demo) should provide some confirmation that the tool is fast enough to provide feedback in real-time.

The capability of this tool is thanks to [Marpa](http://jeffreykegler.github.io/Marpa-web-site/), which makes it possible to describe potentially ambiguous grammars quickly and easily.

## What's the catch?

There are a significant number of languages that cannot be adequately described using only the language shown above. Consider Javascript and HTML. In Javascript, semicolons are optional, meaning that a liberal parser must be able to actively invent tokens in order to parse Javascript found in the wild.

HTML is similarly seldom found in a format that can be described strictly in BNF.

The core library, [marpa](https://github.com/omarroth/marpa), does provide tools for handling these kinds of languages, however this functionality has not yet been implemented into the syntax highlighter.

## Conclusion

I think syntax.cr is likely the easiest way to go from a grammar to a nice-looking highlighter.

All the BNF samples shown above were colorized using syntax.cr, and the [demo](/syntax/demo) should further show the capability of this tool.

For other applications, I would refer readers to the [marpa library](https://github.com/omarroth/marpa) written in Crystal, or the [original SLIF interface](https://metacpan.org/pod/distribution/Marpa-R2/pod/Semantics.pod), written in Perl.
