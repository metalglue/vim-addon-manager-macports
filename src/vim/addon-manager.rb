# vim-addons: command line manager of Vim addons
#
# Copyright (C) 2007 Stefano Zacchiroli
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# $Id: addon-manager.rb 866 2007-01-24 21:27:58Z zack $

require 'fileutils'

require 'vim/common'
require 'vim/constants'

module Vim

  class AddonManager

    def initialize(source_dir, target_dir)
      @source_dir = source_dir
      @target_dir = target_dir
    end

    attr_accessor :source_dir
    attr_accessor :target_dir

    def install(addons)
      installed_files = []
      addons.each do |addon|
	base_dir = (addon.basedir or @source_dir)
	symlink = lambda do |file|
	  dest = File.join(@target_dir, file)
	  dest_dir = File.dirname dest
	  FileUtils.mkdir_p dest_dir unless File.directory? dest_dir
	  FileUtils.ln_sf(File.join(base_dir, file), dest)
	end
	status = addon.status(@target_dir)
	case status.status
	when :broken
	  Vim.info "installing broken addon '#{addon}'"
	  status.missing_files.each(&symlink)
          installed_files.concat(status.missing_files.to_a)
	when :not_installed
	  Vim.info "installing removed addon '#{addon}'"
	  addon.files.each(&symlink)
          installed_files.concat(addon.files.to_a)
        else
          Vim.info "ignoring '#{addon}' which is neither removed nor broken"
	end
      end
      rebuild_tags(installed_files)
    end

    def remove(addons)
      # TODO remove empty directories (recursively toward the top of ~/.vim/,
      # a la rmdir -p)
      removed_files = []
      rmlink = lambda {|file| File.delete(File.join(@target_dir, file)) }
      addons.each do |addon|
	status = addon.status(@target_dir)
	case status.status
	when :installed
	  Vim.info "removing installed addon '#{addon}'"
	  addon.files.each(&rmlink)
          removed_files.concat(addon.files.to_a)
	when :broken
	  Vim.info "removing broken addon '#{addon}'"
          files = (addon.files - status.missing_files)
	  files.each(&rmlink)
          removed_files.concat(files.to_a)
        else
          Vim.info "ignoring '#{addon}' which is neither installed nor broken"
	end
      end
      rebuild_tags(removed_files)
    end

    def disable(addons)
      map_override_lines do |lines|
        addons.each do |addon|  # disable each not yet disabled addon
          if not addon.disabled_by_line
            Vim.warn \
              "#{addon} can't be disabled (since it has no 'disabledby' field)"
            next
          end
          if lines.any? {|line| addon.is_disabled_by? line}
	    Vim.info "ignoring addon '#{addon}' which is already disabled"
	  else
	    Vim.info "disabling enabled addon '#{addon}'"
            lines << addon.disabled_by_line + "\n"
          end
        end
      end
    end

    def amend(addons)
      map_override_lines do |lines|
        addons.each do |addon|
          if not addon.disabled_by_line
            Vim.warn \
              "#{addon} can't be amended (since it has no disabledby field)"
            next
          end
	  if lines.any? {|line| addon.is_disabled_by? line}
	    Vim.info "amending disabled addon '#{addon}'"
	    lines.reject! {|line| addon.is_disabled_by? line}
	  else
	    Vim.info "ignoring addon '#{addon}' which is enabled"
	  end
        end
      end
    end

    def show(addons)
      addons.each do |addon|
        puts "Addon: #{addon}"
        puts "Status: #{addon.status(@target_dir)}"
        puts "Description: #{addon.description}"
        puts ""
      end
    end

    private
    
    def map_override_lines
      override_lines = []
      override_file = Vim.override_file @target_dir
      if File.exist? override_file
        File.open(override_file) do |file|
          override_lines += file.to_a
        end
      end
      checksum = override_lines.hash

      yield override_lines

      if override_lines.empty?
        FileUtils.rm override_file if File.exist? override_file
      elsif override_lines.hash != checksum
        File.open(override_file, 'w') do |file|
          file.write override_lines
        end
      end
    end

    def rebuild_tags(files)
      needs_rebuilding = files.any? {|file| file =~ /^doc\//}
      if needs_rebuilding
        Vim.info 'Rebuilding tags since documentation has been modified ...'
        Vim.system "#{HELPZTAGS} #{File.join(@target_dir, 'doc/')}"
        Vim.info 'done.'
      end
    end

  end

end

