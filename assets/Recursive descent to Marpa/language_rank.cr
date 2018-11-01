languages = File.read("popularity.txt")
github, tiobe = languages.split("----").map { |a| a.split("\n").select { |a| !a.empty? } }

avg_ranking = {} of String => Float64

(github & tiobe).each do |language|
  i = github.index(language).not_nil!.to_f
  j = tiobe.index(language).not_nil!.to_f

  avg_ranking[language] = (i + j) / 2
end

pp avg_ranking.to_a.sort_by! { |k, v| v }.size # => [{"Java", 1.0},        =>          : 
                                               #     {"C", 3.5},           => gcc      : Recursive descent
                                               #     {"JavaScript", 4.0},  => 
                                               #     {"Python", 4.5},      => 
                                               #     {"C++", 4.5},         => 
                                               #     {"PHP", 5.5},         => 
                                               #     {"Objective-C", 6.0}, => 
                                               #     {"C#", 6.5},          => csparser : Recursive descent
                                               #     {"Ruby", 7.5},        => ripper   : Bison(?)
                                               #     {"Perl", 12.5}]       => Custom lexer with modified bison parser
