require "json"

# Word, along with array of environments
contexts = {} of String => Array({String, String})

# Only look at first N lines
n = -1

i = 0
File.each_line("dataset.txt") do |line|
  print "#{i}\r"
  if i == n
    break
  end
  i += 1

  line = line.downcase
  line = [""] + line.split(" ") + [""]
  line.each_cons(3, true) do |cons|
    word = cons[1]

    #              before,  after
    environment = {cons[0], cons[2]}

    # If word already has environment, skip
    if contexts[word]?.try &.includes? environment
      next
    end

    if contexts.has_key? word
      contexts[word] << environment
    else
      contexts[word] = [environment]
    end
  end
end

puts "#{i} lines"

i = 0
filtered = {} of String => Array({String, String})
contexts.each do |word, environments|
  print "#{i}\r"
  i += 1

  all_environments = contexts.select { |k, v| k != word }.values.flatten
  unique_environments = environments - all_environments
  shared_environments = environments - unique_environments

  if !shared_environments.empty?
    filtered[word] = shared_environments
  end
end

puts "#{i} words"
puts "#{contexts.size - filtered.size} discarded"
File.write("contexts.json", filtered.to_json)
