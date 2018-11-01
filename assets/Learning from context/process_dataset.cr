require "xml"
require "html"

filename = "simplewiki.txt"
File.write(filename, "")

read = false
i = 0
File.each_line("simplewiki.xml") do |line|
  print "#{i}\r"
  i += 1

  if line.starts_with? %(      <text xml:space="preserve">)
    line = line.lchop(%(      <text xml:space="preserve">))
    read = true
  end

  if read
    File.write(filename, HTML.unescape(line.rchop("</text>")), mode: "a")
    File.write(filename, "\n", mode: "a")
  end

  if line.ends_with? %q(</text>)
    File.write(filename, "<<<<<<<<\n", mode: "a")
    read = false
  end
end
puts "#{i} lines"

File.write("sentences.txt", "")

i = 0
File.each_line(filename) do |line|
  print "#{i}\r"
  i += 1

  if line.starts_with?("{{") || line.starts_with?("}}")
    next
  end

  if line.starts_with?("==") && line.ends_with?("==")
    next
  end

  if line.starts_with?("*")
    next
  end

  if line.starts_with?("|")
    next
  end

  if line.starts_with?("#")
    next
  end

  if line.starts_with?("!")
    next
  end

  if !line.ends_with?(/[.]/)
    next
  end

  line = line.gsub("''", "")
  line = line.gsub("[[", "")
  line = line.gsub("]]", "")

  line = HTML.unescape(line)

  if line.match(/^([A-Z][a-zA-Z, ]{2,}[.])+$/)
    line.split(/[.]/).each do |sentence|
      if sentence == ""
        next
      end

      sentence = sentence + " .\n"

      File.write("sentences.txt", sentence, mode: "a")
    end
  end
end
puts "#{i} lines"
