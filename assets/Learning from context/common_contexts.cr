require "json"

counts = {} of Array(String) => Int32

contexts = JSON.parse(File.read("contexts.json"))
environments = contexts.as_h.map { |k, v| v.as_a }.flatten
environments.each do |environment|
  environment = environment.as_a.map { |a| a.as_s }

  if counts.has_key? environment
    counts[environment] += 1
  else
    counts[environment] = 1
  end
end

counts = counts.to_a.sort_by { |k, v| v }.select { |k, v| v > 20 }

counts.each do |environment, count|
  puts "#{environment} : #{environments.count(environment)}"
end
