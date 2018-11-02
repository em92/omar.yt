require "compiler/crystal/syntax"
require "compiler/crystal/syntax/ast"
require "json"
require "option_parser"

input = File.read("work/ast.cr")
output = nil
pretty_print = true

OptionParser.parse! do |parser|
  parser.banner = "Usage: ast [arguments]"
  parser.on("-i FILE", "--input=FILE", "Input file") { |file| input = File.read(file) }
  parser.on("-o FILE", "--output=FILE", "Output file (default: STDOUT") { |file| output = file }
  parser.on("-p STRING", "--puts=STRING", "Input string") { |string| input = string }
  parser.on("-b BEAUTIFY", "--beautify=BEAUTIFY", "Pretty print AST? (default: #{pretty_print})") { |beautify| pretty_print = beautify.downcase == "true" }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

ast = Crystal::Parser.parse(input)
json = Crystal.print_ast ast

if pretty_print
  json = JSON.parse(json).to_pretty_json
end

if output
  File.write(output.not_nil!, json)
else
  puts json
end

module Crystal
  def self.print_ast(node)
    ast_visitor = PrintASTVisitor.new
    node.accept ast_visitor

    json = ast_visitor.json
    json.end_document
    json.flush

    output = ast_visitor.output
    output.rewind

    return output.gets_to_end
  end

  class PrintASTVisitor < Visitor
    property output
    property json

    def initialize
      @output = IO::Memory.new
      @json = JSON::Builder.new(@output)
      @json.start_document
    end

    def end_visit(node)
      @json.end_array
      @json.end_object
    end

    def visit(node : Nop)
      puts_ast(node)
    end

    def visit(node : NilLiteral)
      puts_ast(node)
    end

    def visit(node : BoolLiteral)
      puts_ast(node, {"value" => node.value})
    end

    def visit(node : NumberLiteral)
      puts_ast(node, {"value" => node.value, "kind" => node.kind})
    end

    def visit(node : CharLiteral)
      puts_ast(node, {"value" => node.value.to_s})
    end

    def visit(node : StringLiteral)
      puts_ast(node, {"value" => node.value})
    end

    def visit(node : SymbolLiteral)
      puts_ast(node, {"value" => node.value})
    end

    def visit(node : ArrayLiteral)
      puts_ast(node)

      node.name.try &.accept self
      node.elements.each &.accept self
      node.of.try &.accept self

      false
    end

    def visit(node : HashLiteral)
      puts_ast(node)

      node.name.try &.accept self
      node.entries.each do |entry|
        entry.key.accept self
        entry.value.accept self
      end
      if of = node.of
        of.key.accept self
        of.value.accept self
      end

      false
    end

    def visit(node : RangeLiteral)
      puts_ast(node, {"exclusive" => node.exclusive?})

      node.from.accept self
      node.to.accept self

      false
    end

    def visit(node : RegexLiteral)
      puts_ast(node, {"options" => node.options})

      node.value.accept self

      false
    end

    def visit(node : TupleLiteral)
      puts_ast(node)

      node.elements.each &.accept self

      false
    end

    def visit(node : Block)
      puts_ast(node)

      node.args.each &.accept self
      node.body.accept self

      false
    end

    def visit(node : Call)
      puts_ast(node, {"name" => node.name, "global" => node.global?, "name_column_number" => node.name_column_number, "has_parenthesis" => node.has_parentheses?})

      node.obj.try &.accept self
      node.args.each &.accept self
      node.named_args.try &.each &.accept self
      node.block_arg.try &.accept self
      node.block.try &.accept self

      false
    end

    def visit(node : NamedArgument)
      puts_ast(node, {"name" => node.name})

      node.value.accept self

      false
    end

    def visit(node : If)
      puts_ast(node)

      node.cond.accept self
      node.then.accept self
      node.else.accept self

      false
    end

    def visit(node : Unless)
      puts_ast(node)

      node.cond.accept self
      node.then.accept self
      node.else.accept self

      false
    end

    def visit(node : IfDef)
      puts_ast(node)

      node.cond.accept self
      node.then.accept self
      node.else.accept self

      false
    end

    def visit(node : Assign)
      puts_ast(node)

      node.target.accept self
      node.value.accept self

      false
    end

    def visit(node : MultiAssign)
      puts_ast(node)

      node.targets.each &.accept self
      node.values.each &.accept self

      false
    end

    def visit(node : InstanceVar)
      puts_ast(node, {"name" => node.name})
    end

    def visit(node : ReadInstanceVar)
      puts_ast(node, {"name" => node.name})

      node.obj.accept self

      false
    end

    def visit(node : BinaryOp)
      puts_ast(node)

      node.left.accept self
      node.right.accept self

      false
    end

    def visit(node : Arg)
      puts_ast(node, {"name" => node.name})

      node.default_value.try &.accept self
      node.restriction.try &.accept self
      # end
      false
    end

    def visit(node : Fun)
      puts_ast(node)

      node.inputs.try &.each &.accept self
      node.output.try &.accept self

      false
    end

    def visit(node : BlockArg)
      puts_ast(node, {"name" => node.name})

      node.fun.try &.accept self

      false
    end

    def visit(node : UnaryExpression)
      puts_ast(node)

      node.exp.accept self

      false
    end

    def visit(node : VisibilityModifier)
      puts_ast(node, {"modifier" => node.modifier})

      node.exp.accept self

      false
    end

    def visit(node : IsA)
      puts_ast(node)

      node.obj.accept self
      node.const.accept self

      false
    end

    def visit(node : RespondsTo)
      puts_ast(node, {"name" => node.name})

      # node.receiver

      false
    end

    def visit(node : Require)
      puts_ast(node, {"string" => node.string})
    end

    def visit(node : When)
      puts_ast(node)

      node.conds.each &.accept self
      node.body.accept self

      false
    end

    def visit(node : Case)
      puts_ast(node)

      node.whens.each &.accept self
      node.else.try &.accept self

      false
    end

    def visit(node : ImplicitObj)
      puts_ast(node)
    end

    def visit(node : Path)
      puts_ast(node, {"names" => node.names, "global" => node.global?})
    end

    def visit(node : While)
      node.cond.accept self
      node.body.accept self

      false
    end

    def visit(node : Until)
      node.cond.accept self
      node.body.accept self

      false
    end

    def visit(node : Generic)
      puts_ast(node)

      node.name.accept self
      node.type_vars.each &.accept self

      false
    end

    def visit(node : DeclareVar)
      puts_ast(node)

      node.var.accept self
      node.declared_type.accept self

      false
    end

    def visit(node : Rescue)
      puts_ast(node, {"name" => node.name})

      node.body.accept self
      node.types.try &.each &.accept self

      false
    end

    def visit(node : ExceptionHandler)
      puts_ast(node)

      node.body.accept self
      node.rescues.try &.each &.accept self
      node.else.try &.accept self
      node.ensure.try &.accept self

      false
    end

    def visit(node : FunLiteral)
      puts_ast(node)

      node.def.accept self

      false
    end

    def visit(node : ASTNode)
      str = node.responds_to?(:name) ? node.name : ""
      puts_ast(node, {"name" => str.to_s})
    end

    private def puts_ast(node : ASTNode, str = {} of String => String)
      @json.start_object
      @json.field "type", node.class.to_s.split("::").last
      @json.field "attributes", str
      @json.field "location", node.location.to_s
      @json.string "children"
      @json.start_array
    end
  end
end
