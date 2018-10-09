require "json"

contexts = JSON.parse(File.read("contexts.json")).as_h

similarities = {} of String => Array({String, Float64})

# Cutoff for similarity
n = 0.2

i = 0
contexts.each do |word, environments|
  print "#{i}\r"
  i += 1

  environments = environments.as_a.map { |a| a.as_a.map { |b| b.as_s } }

  contexts.each do |other_word, other_environments|
    other_environments = other_environments.as_a.map { |a| a.as_a.map { |b| b.as_s } }

    # Skip if we're comparing word to itself
    if word == other_word
      next
    end

    difference = environments - other_environments
    similarity = (environments.size - difference.size).to_f / environments.size

    if similarity > n
      if similarities.has_key? word
        similarities[word] << {other_word, similarity}
      else
        similarities[word] = [{other_word, similarity}]
      end
    end
  end
end

puts "#{i} words"
File.write("similarities.json", similarities.to_pretty_json)
