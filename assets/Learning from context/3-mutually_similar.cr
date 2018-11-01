require "json"

similarities = JSON.parse(File.read("similarities.json")).as_h

mutual_similarities = {} of String => Array(String)

i = 0
similarities.each do |word, similars|
  print "#{i}\r"
  i += 1

  mutuals = [] of String
  similars.as_a.each do |other_word|
    other_word = other_word[0]

    if word == other_word
      next
    end

    if similarities[other_word]?.try &.as_a.map { |a| a[0] }.includes? word
      mutuals << other_word.as_s
    end
  end

  if !mutuals.empty?
    mutual_similarities[word] = mutuals
  end
end

puts "#{i} words"
puts "#{similarities.size - mutual_similarities.size} discarded"
File.write("mutual_similarities.json", mutual_similarities.to_pretty_json)
