File.write("dataset.txt", "")

i = 1
File.each_line("wkpd.txt") do |line|
  print "#{i}\r"
  i += 1

  line = line.gsub("`` ", "")
  line = line.gsub(" ''", "")
  line = line.gsub("HEADING", "")
  line = line.strip

  if !line.match(/^[A-Za-z0-9' ]+[!?.]$/)
    next
  end

  if !line.starts_with?(/[A-Z]/)
    line
    next
  end

  if line.count(' ') < 2
    next
  end

  File.write("dataset.txt", line + "\n", mode: "a")
end
