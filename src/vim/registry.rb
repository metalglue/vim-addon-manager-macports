# vim-addons: command line manager of Vim addons
#
# Copyright (C) 2007 Stefano Zacchiroli
#
# This program is free software, you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 2 as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# $Id: registry.rb 866 2007-01-24 21:27:58Z zack $

require 'find'
require 'set'
require 'yaml'

require 'vim/common'

module Vim

  # an addon status is one of the following
  # - :not_installed
  # - :installed
  # - :broken (missing_files attribute is then used to list not installed
  # files)
  #
  AddonStatusStruct = Struct.new(:status, :missing_files)

  class AddonStatus < AddonStatusStruct

    def initialize(*args)
      super(*args)
      @disabled = false
    end

    attr_accessor :disabled

    def to_s
      if @disabled
        'disabled'
      else
        case status
        when :installed
            'installed'
        when :not_installed
            'removed'
        when :broken
            s = 'broken'
            s << " (missing: #{missing_files.join ', '})" if Vim.verbose?
            s
        end
      end
    end

  end


  class Addon

    def initialize(yaml, basedir)
      @basedir = (yaml['basedir'] or basedir)
      @description = yaml['description']
      @name = yaml['addon']

      @files = Set.new yaml['files']
      raise ArgumentError.new('empty addon') if @files.size == 0

      @disabled_by_line = yaml['disabledby']
      if @disabled_by_line then
        @disabled_by_RE = /^\s*#{Regexp.escape @disabled_by_line}\s*$/
      else
        @disabled_by_RE = nil
      end

    end

    # return the status of the self add-on wrt a target installation
    # directory, and the system wide installation directory.
    # A status is a ternary value: :not_installed (the addon is not installed
    # at all), :installed (the addon is completely installed), :broken (the
    # addon is only partially installed)
    #
    def status(target_dir)
      expected = @files.collect {|f| File.join(target_dir, f)}
      installed = expected.select do |f|
        case
        when (File.exist? f)
          true
        #when (File.symlink? f)
          #(File.readlink f) ==
          #(File.join @basedir, f.gsub(/^#{Regexp.escape target_dir}\/*/, ''))
        #when (File.file? f)
          #true
        else
          false
        end
      end

      status =
        if installed.size == expected.size
          AddonStatus.new :installed
        elsif installed.size == 0
          AddonStatus.new :not_installed
        else
          missing = expected - installed
          prefix = /^#{Regexp.escape target_dir}\/+/o
          missing.collect! {|f| f.gsub(prefix, '')}
          AddonStatus.new(:broken, missing)
        end

      status.disabled = is_disabled_in? target_dir
      status
    end

    def to_s
      name
    end

    def <=>(other)
      self.name <=> other.name
    end

    # checks if a given line (when present in a Vim configuration file) is
    # suitable for disabling the addon
    #
    def is_disabled_by?(line)
      return false unless @disabled_by_RE # the addon can't be disabled if no
                                          # disabledby field has been provided
      line =~ @disabled_by_RE ? true : false
    end

    attr_reader :basedir
    attr_reader :description
    attr_reader :files
    attr_reader :name
    attr_reader :disabled_by_line
    alias_method :addon, :name

    private

    # checks whether the addon is disabled wrt a given target installation dir
    #
    def is_disabled_in?(target_dir)
      return false unless File.exist?(Vim.override_file(target_dir))
      File.open(Vim.override_file(target_dir)) do |file|
        file.any? {|line| is_disabled_by? line}
      end
    end

  end


  class AddonRegistry

    include Enumerable

    def initialize(registry_dir, source_dir)
      @basedir = source_dir # default basedir, can be overridden by addons
      @addons = {}
      AddonRegistry.each_addon(registry_dir, @basedir) {|a| @addons[a.name] = a}
    end

    def [](name)
      @addons[name]
    end

    def each
      @addons.each_value {|a| yield a}
    end

    def AddonRegistry.each_addon(dir, basedir)
      Find.find(dir) do |path|
	# selects .yaml files (non-recursively) contained in dir
	next if path == dir
	Find.prune if File.directory? path
	if File.file? path
	  Find.prune if path !~ /\.yaml$/
	  File.open path do |f|
	    YAML.load_documents f do |ydoc|
	      yield(Addon.new(ydoc, basedir)) if ydoc
	    end
	  end
	end
      end
    end

  end

end

