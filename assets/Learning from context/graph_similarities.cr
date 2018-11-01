require "json"

mutual_similarities = JSON.parse(File.read("mutual_similarities.json")).as_h
mutual_similarities = Hash.zip(mutual_similarities.keys, mutual_similarities.values.map { |v| v.as_a.map { |a| a.as_s } })

filename = "mutual_graph.gv"

vertices = [] of Array(String)

i = 0
mutual_similarities.each do |word, mutuals|
  print "#{i}\r"
  i += 1

  mutuals.each do |mutual|
    vertex = [word, mutual]
    vertex.sort!

    if !vertices.includes? vertex
      vertices << vertex
    end
  end
end

puts vertices.size

start_graph = <<-END_GRAPH
graph mutual_graph {\n
END_GRAPH
File.write(filename, start_graph)
vertices.each do |vertex|
  File.write(filename, %(    "#{vertex[0]}" -- "#{vertex[1]}";\n), mode: "a")
end
File.write(filename, "}\n", mode: "a")
