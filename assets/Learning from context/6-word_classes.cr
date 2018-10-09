require "json"

mutual_similarities = JSON.parse(File.read("mutual_similarities.json")).as_h
mutual_similarities = Hash.zip(mutual_similarities.keys, mutual_similarities.values.map { |v| v.as_a.map { |a| a.as_s } })

classes = [] of Array(String)

i = 0
mutual_similarities.each do |word, mutuals|
  print "#{i}\r"
  i += 1

  clusters = find_clusters([word], mutual_similarities)
  clusters.uniq!

  clusters.each do |cluster|
    if !classes.includes? cluster
      classes << cluster.as(Array(String))
    end
  end
end

puts "#{i} words"
puts "#{classes.size} classes"

# Remove classes that are subsets of other classes
classes.each do |cluster|
  classes.each do |other_cluster|
    if (other_cluster & cluster).size.to_f/cluster.size.to_f == 0.9
      if other_cluster.size > cluster.size
        classes.delete(cluster)
      else
        classes.delete(other_cluster)
      end
    end
  end
end
puts "#{classes.size} discarded"

File.write("classes.json", classes.to_pretty_json)

def find_clusters(path : Array(String), graph)
  current_node = path.pop
  clusters = [] of Array(String)

  if (graph[current_node] & path) == path
    path << current_node

    (graph[current_node] - path).each do |node|
      cluster = find_clusters(path + [node], graph)
      if !cluster.empty?
        if cluster.as?(Array(String))
          clusters << cluster.as(Array(String))
        else
          clusters += cluster.as(Array(Array(String)))
        end
      end
    end

    return clusters
  else
    return path.sort
  end
end

graph = {
  "a" => ["b", "c", "e"],
  "b" => ["a", "c"],
  "c" => ["a", "b", "d", "e"],
  "d" => ["c"],
  "e" => ["a", "c"],
}
