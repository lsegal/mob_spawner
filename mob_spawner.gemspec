require File.dirname(__FILE__) + "/lib/mob_spawner"
Gem::Specification.new do |s|
  s.name          = "mob_spawner"
  s.summary       = "Manages and spawns worker threads to run arbitrary shell commands."
  s.description   = <<-eof
MobSpawner manages worker threads that can run arbitrary commands and report
results. Unlike distributed queues, MobSpawner is self-contained and perfect
for small batch scripts that need to run multiple independent jobs.
  eof
  s.version       = MobSpawner::VERSION
  s.author        = "Loren Segal"
  s.email         = "lsegal@soen.ca"
  s.homepage      = "http://github.com/lsegal/mob_spawner"
  s.platform      = Gem::Platform::RUBY
  s.files         = Dir.glob("{lib}/**/*") + ['README.md']
  s.require_paths = ['lib']
end