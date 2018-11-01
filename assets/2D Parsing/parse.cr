require "marpa"

overlapping_boxes = <<-END_BOXES
      ┌──────────────┐
      │              │
      │              │
      │              │
      │              │
      │              │
      │              │
      │              │
      │              │
      │              │
      │              │  ┌───────────────────────┐
      └──────────────┘  │                       │
          ┌┐            │      ┌───┐            │
┌───┐     └┘   ┌┐       │      │   │   ┌───┐    │
│   │          └┘       │      └───┘   │   │    │
└───┘   ┌──────────┐    │              └───┘    │
        │          │    └───────────────────────┘
        │    ┌┐    │
        │    └┘    │
        │          │
        └──────────┘

                          ┌───────┐
                          │       │
                          └───────┘
END_BOXES

boxes = <<-END_BOXES
┌──────────────┐
│              │
│              │
│              │
│              │
│              │
│              │
└──────────────┘

┌───┐             ┌────────────┐
│   │             │            │
└───┘             │            │
  ┌──────────┐    │            │
  │          │    │            │
  │          │    │            │
  │          │    │            │
  │          │    │            │
  └──────────┘    └────────────┘
                    ┌───────┐
                    │       │
                    └───────┘
END_BOXES

line_bnf = <<-END_BNF
:start ::= elements

elements ::= element*
element ::= top | middle | bottom

top      ~ /┌─*┐/
middle   ~ /│ *│/
bottom   ~ /└─*┘/

space    ~ [ ]+
:discard ~ space

:lexeme ~ top    pause => after event => top
:lexeme ~ middle pause => after event => middle
:lexeme ~ bottom pause => after event => bottom
END_BNF

class Events < Marpa::Events
  property events

  def initialize
    @events = [] of {Int32, Int32, String}
  end

  def top(context)
    item_start = context.values.last_key
    item_value = context.values.last_value
    @events << {item_start, item_start + item_value.size, "top"}
  end

  def middle(context)
    item_start = context.values.last_key
    item_value = context.values.last_value
    @events << {item_start, item_start + item_value.size, "middle"}
  end

  def bottom(context)
    item_start = context.values.last_key
    item_value = context.values.last_value
    @events << {item_start, item_start + item_value.size, "bottom"}
  end
end

column_bnf = <<-END_BNF
:start ::= boxes
boxes ::= box*
box ::= 'top' middles 'bottom'

middles ::= middle*
middle  ~ 'middle'

space ~ [ ]+
:discard ~ space

:lexeme ~ box
END_BNF

i = 0
boxes.each_line do |line|
  parser = Marpa::Parser.new
  events = Events.new
  parser.parse(line, line_bnf, events: events)

  puts " #{i.to_s.rjust(2)} : #{events.events}"

  i += 1
end
parser = Marpa::Parser.new

box_coords = [] of {Int32, Int32, Int32, Int32}
