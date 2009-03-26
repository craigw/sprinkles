require 'rake'

Gem::Specification.new do |s|
  s.name = %Q(sprinkles)
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = %W(Craig R Webster)
  s.date = %Q(2009-03-26)
  s.description = %Q(Sprinkles is a minimal framework for developing IRC bots in Ruby)
  s.email = %Q(craig@barkingiguana.com)
  s.files = Dir[File.dirname(__FILE__) + "/lib/**/*.rb"]
  s.has_rdoc = true
  s.homepage = %Q(http://barkingiguana.com/~craig/sprinkles)
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.summary = %Q(A minimal framework for developing IRC bots)
end