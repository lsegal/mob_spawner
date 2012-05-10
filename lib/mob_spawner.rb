require 'open3'

# MobSpawner manages worker threads that can run arbitrary commands and report
# results. Unlike distributed queues, MobSpawner is self-contained and perfect
# for small batch scripts that need to run multiple independent jobs.
class MobSpawner
  VERSION = '1.0.0'

  # Represents a command to be called by the spawner. Can also hold environment
  # variables and arbitrary client data to identify the object.
  class Command
    # @return [String] the command to be executed by the spawner
    attr_accessor :command

    # @return [Hash{String=>String}] any environment variables to be set
    #   when running the command.
    attr_accessor :env

    # @return [Object] arbitrary client data used to identify the command
    #   object.
    attr_accessor :data

    # Creates a new command.
    #
    # @overload initialize(opts = {})
    #   @param [Hash{Symbol=>Object}] opts option data to be passed during
    #     initialization. Keys can be any attribute defined on this class,
    #     such as {#command}, {#env} or {#data}.
    # @overload initialize(cmd, env = {}, data = nil)
    #     @param [String] cmd the command to execute
    #     @param [Hash{String=>String}] env environment variables to be set
    #       when running the command
    #     @param [Object] data any client data to be set on the command object
    def initialize(cmd, env = {}, data = nil)
      self.env = {}
      if cmd.is_a?(Hash)
        cmd.each do |k, v|
          meth = "#{k}="
          send(meth, v) if respond_to?(meth)
        end
      else
        self.command = cmd
        self.env = env
        self.data = data
      end
    end
  end

  # @return [Fixnum] the number of workers to run, defaults to 3.
  attr_accessor :num_workers

  # @return [Array<Command,String>] a list of commands to be executed. Note that
  #   if a command is a String, it will eventually be converted into a {Command}
  #   object.
  attr_accessor :commands

  # @return [Array<Proc>] a list of callbacks to be called before each worker.
  #   Use {#before_worker} instead of setting the callbacks list directly.
  # @see #before_worker
  attr_accessor :before_callbacks

  # @return [Array<Proc>] a list of callbacks to be called after each worker.
  #   Use {#after_worker} instead of setting the callbacks list directly.
  # @see #after_worker
  attr_accessor :after_callbacks

  # Creates a new spawner, use {#run} to run it.
  #
  # @overload initialize(opts = {})
  #   @param [Hash{Symbol=>Object}] opts option data to be passed during
  #     initialization. Keys can be any attribute defined on this class,
  #     such as {#num_workers}, {#commands}, etc.
  # @overload initialize(*commands)
  #   @param [Array<String>] commands a list of commands to be run using
  #     default settings.
  def initialize(*commands)
    super()
    self.num_workers = 3
    self.commands = []
    self.before_callbacks = []
    self.after_callbacks = []
    if commands.size == 1 && commands.first.is_a?(Hash)
      setup_options(commands.first)
    else
      self.commands = commands.flatten
    end
  end

  # Runs the spawner, initializing all workers and running the commands.
  def run
    self.commands = commands.map {|c| c.is_a?(Command) ? c : Command.new(c) }
    workers = []
    num_workers.times { workers << [] }
    divide_to_workers(workers, commands)
    threads = []
    workers.each_with_index do |worker, i|
      next if worker.size == 0
      threads << Thread.new do
        worker.each do |cmd|
          data = {:worker => i+1, :command => cmd}
          before_callbacks.each {|cb| cb.call(data) }
          begin
            output, status = Open3.capture2e(cmd.env, cmd.command)
            data.update(:output => output, :status => status)
          rescue => exc
            data.update(:exception => exc, :status => 256)
          end
          after_callbacks.each {|cb| cb.call(data) }
        end
      end
    end
    while threads.size > 0
      threads.dup.each do |thr|
        thr.join(0.1)
        threads.delete(thr) unless thr.alive?
      end
    end
  end

  # Creates a callback that is executed before each worker is run.
  #
  # @yield [data] worker information
  # @yieldparam [Hash{Symbol=>Object}] data information about the worker
  #   thread. Valid keys are:
  #
  #   * +:worker+ - the worker number (starting from 1)
  #   * +:command+ - the {Command} object about to be run
  def before_worker(&block)
    before_callbacks << block
  end

  # Creates a callback that is executed after each worker is run.
  #
  # @yield [data] worker information
  # @yieldparam [Hash{Symbol=>Object}] data information about the worker
  #   thread. Valid keys are:
  #
  #   * +:worker+ - the worker number (starting from 1)
  #   * +:command+ - the {Command} object about to be run
  #   * +:output+ - all stdout and stderr output from the command
  #   * +:status+ - the status code from the exited command
  #   * +:exception+ - if a Ruby exception occurred during execution
  def after_worker(&block)
    after_callbacks << block
  end

  private

  def setup_options(opts)
    opts.each do |k, v|
      meth = "#{k}="
      send(meth, v) if respond_to?(meth)
    end
  end

  def divide_to_workers(workers, commands)
    num_workers = workers.size
    commands.each_with_index do |command, i|
      workers[i % num_workers] << command
    end
  end
end
