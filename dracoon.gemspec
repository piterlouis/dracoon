Gem::Specification.new do |s|
  s.name        = "dracoon"
  s.version     = "1.0.0.beta2"
  s.date        = "2014-03-30"
  s.summary     = "Dracoon, the amaizing tool to compile interactive fiction books."
  s.description = "Dracoon is a language and compiler to write interactive fiction books."
  s.authors     = ["Pedro L. Morales"]
  s.email       = "piterlouis@gmail.com"
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md"
  ]
  s.files = [
    "LICENSE",
    "README.md",
    "bin/dracoon",
    "lib/dracoon.rb",
    "lib/dracoon_core.rb",
    "lib/dracoon_nodes.rb",
    "lib/dracoon_sqlite.rb",
    "dracoon.gemspec"
  ]
  s.homepage    = "https://github.com/piterlouis/dracoon"
  s.license     = "GPL-2"
  s.executables = ["dracoon"]
  s.add_runtime_dependency "treetop", ["~> 1.5"]
  s.add_runtime_dependency "uglifier", ["~> 2.5"]
  s.add_runtime_dependency "sqlite3", ["~> 1.3"]
end
