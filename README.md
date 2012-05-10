# MobSpawner

MobSpawner manages worker threads that can run arbitrary commands and report
results. Unlike distributed queues, MobSpawner is self-contained and perfect
for small batch scripts that need to run multiple independent jobs.

## Usage

The simplest usage of MobSpawner is:

```ruby
commands = ["rvm install 1.8.6", "rvm install 1.9.2", "rvm install rbx"]
MobSpawner.new(commands).run
```

Which will attempt to run the 3 commands concurrently across the default of
3 worker threads. By default commands do not report output; to get command output,
use callbacks discussed in the next section.

## Callbacks

In addition to simply running worker threads, you can also receive reports
about each worker's execution results using callbacks. To setup a spawner
with callbacks, use {MobSpawner#before_worker} and {MobSpawner#after_worker}:

```ruby
spawner = MobSpawner.new("command1", "command2", "command3")
spawner.before_worker do |data|
  puts "Worker #{data[:worker]} about to run #{data[:command].command}"
end
spawner.after_worker do |data|
  puts "Worker #{data[:worker]} exited with status #{data[:status]}"
  puts "Output:"
  puts data[:output]
end
spawner.run
```

## License & Copyright

MobSpawner is licensed under the MIT license, &copy; 2012 Loren Segal
