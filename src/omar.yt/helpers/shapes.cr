require "marpa"

module Shapes
  class ShapeActions < Marpa::Actions
    @first_loop = true

    def abs(context)
      body = context.as(Array).flatten.join("").strip("|")
      "Math.abs(#{body})"
    end

    def pow(context)
      context[1] = "**"
      context
    end

    def build_loop(context)
      plane = context[0][1].as(String).split("")
      tuple = context[1][1].as(Array)
      tuple.delete(",")
      range = context[2]

      delta = context[3]?
      delta ||= ["d", "=", "0.1"]

      if delta.is_a?(Array)
        delta = delta.as(Array).flatten
      end

      if delta[2].to_f == 0.0
        raise "Delta cannot be zero"
      end

      x = tuple[plane.index("x") || 10]?
      y = tuple[plane.index("y") || 10]?
      z = tuple[plane.index("z") || 10]?

      if x.is_a?(Array)
        x = x.as(Array).flatten.join("")
      end

      if y.is_a?(Array)
        y = y.as(Array).flatten.join("")
      end

      if z.is_a?(Array)
        z = z.as(Array).flatten.join("")
      end

      if @first_loop
        x ||= "0.0"
        y ||= "0.0"
        z ||= "0.0"

        inner_loop = <<-END_LOOP
      var start_point = #{range[1].as(Array).flatten.join("")};
      var end_point = #{range[5].as(Array).flatten.join("")};
      var delta = #{delta[2]};
      
      var points = [];
      
      for (t = start_point; t + delta <= end_point; t += delta) {
          points.push({x: #{x}, y: #{y}, z: #{z}});
      }
      
      END_LOOP

        @first_loop = false
      else
        x ||= "points[i].x"
        y ||= "points[i].y"
        z ||= "points[i].z"

        inner_loop = <<-END_LOOP
      var start_point = #{range[1].as(Array).flatten.join("")};
      var end_point = #{range[5].as(Array).flatten.join("")};
      var delta = #{delta[2]};
      
      var new_points = [];
      
      for (i = 0; i < points.length; i++) {
          for (t = start_point; t + delta <= end_point; t += delta) {
              new_points.push({x: #{x}, y: #{y}, z: #{z}});
          }
      }
      
      END_LOOP
      end

      inner_loop
    end

    def variable_definition(context)
      variable = context[0]
      body = context[2]

      "#{variable} = #{body}\n"
    end

    def variable_call(context)
      variable = context.as(Array).flatten.join("").downcase

      case variable
      when "e"
        "Math.E"
      when "pi"
        "Math.PI"
      when "x"
        "points[i].x"
      when "y"
        "points[i].y"
      when "z"
        "points[i].z"
      else
        variable
      end
    end

    def function_definition(context)
      variable = context[0]
      parameters = context[1].as(Array).flatten.join("")
      body = context[3]

      "function #{variable}#{parameters} {\nreturn #{body}\n}\n"
    end

    def function_call(context)
      function_name = context[0]
      body = context[2].as(Array).flatten.join("")

      case function_name
      when "sin"
        "Math.sin(#{body})"
      when "asin", "arcsin"
        "Math.asin(#{body})"
      when "csc"
        "(1/Math.sin(#{body})"
      when "cos"
        "Math.cos(#{body})"
      when "acos", "arccos"
        "Math.acos(#{body})"
      when "sec"
        "(1/Math.cos(#{body})"
      when "tan"
        "Math.tan(#{body})"
      when "atan"
        "Math.atan(#{body})"
      when "cot"
        "(1/Math.tan(#{body})"
      when "max"
        "Math.max(#{body})"
      when "min"
        "Math.min(#{body})"
      when "sqrt"
        "Math.sqrt(#{body})"
      else
        "#{function_name}(#{body})"
      end
    end
  end

  ShapeGrammar = <<-'END_BNF'
  :start ::= statements
  statements ::= statement+
  statement ::= function
  | expression
  | plane tuple range action => build_loop
  | plane tuple range delta action => build_loop

  tuple ::= '{' expression_seq '}'
  plane ::= ':' variable
  delta ::= 'd' '=' number
  expression_seq ::= expression* separator => ','

  function ::= variable '=' expression action => variable_definition
  | variable parameters '=' expression action => function_definition

  parameters ::= '(' variable_seq ')'

  variable_seq ::= variable separator => ',' proper => 0
  variable ::= word action => variable_call
  word ~ [a-zA-Z]+

  range ::= '{' expression op variable op expression '}'
  op ::= '<=' | '<' | '='

  expression ::= number
  | '(' expression ')'
  || expression '^' expression action => pow
  || expression '*' expression
  | expression '/' expression
  || expression '+' expression
  | expression '-' expression
  || variable '(' expression_seq ')' action => function_call
  || '|' expression '|' action => abs
  | variable
  | '-' variable

  number ~ /-?([\d]+)(\.\d+)?([eE][+-]?\d+)?/

  :discard ~ whitespace
  whitespace ~ [\s]+

  :discard ~ comment
  comment ~ /#[^\n]*/

  :discard ~ <this helps the parser know where in the original input markers should be placed>
  <this helps the parser know where in the original input markers should be placed> ~ [\x{feff}]
  END_BNF

  JSBoilerplate = <<-'END_JS'
  var geometry = new THREE.Geometry();

  for (i = 0; i < new_points.length ; i++) {
      geometry.vertices.push(
          new THREE.Vector3(new_points[i].x,new_points[i].y,new_points[i].z)
      )
  }

  var material = new THREE.PointsMaterial({
      size: 0.01
  });

  var particles = new THREE.Points(geometry, material);
  scene.add(particles);
  END_JS
end
