# vim-addons: command line manager of Vim addons
#
# Copyright (C) 2007 Stefano Zacchiroli
#
# This program is free software, you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 2 as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# $Id: addon-manager.rb 866 2007-01-24 21:27:58Z zack $

require 'fileutils'

require 'vim/common'

module Vim

  class AddonManager

    def initialize(source_dir, target_dir)
      @source_dir = source_dir
      @target_dir = target_dir
    end

    attr_accessor :source_dir
    attr_accessor :target_dir

    def install(addons)
      addons.each do |a|
	base_dir = (a.basedir or @source_dir)
	symlink = lambda do |f|
	  dest = File.join(@target_dir, f)
	  dest_dir = File.dirname dest
	  FileUtils.mkdir_p dest_dir unless File.directory? dest_dir
	  FileUtils.ln_sf(File.join(base_dir, f), dest)
	end
	status = a.status(@target_dir)
	case status.status
	when :broken
	  status.missing_files.each(&symlink)
	when :not_installed
	  a.files.each(&symlink)
	end
      end
    end

    def remove(addons)
      # TODO remove empty directories (recursively toward the top of ~/.vim/,
      # a la rmdir -p)
      rmlink = lambda {|f| File.delete(File.join(@target_dir, f)) }
      addons.each do |a|
	status = a.status(@target_dir)
	case status.status
	when :installed
	  a.files.each(&rmlink)
	when :broken
	  (a.files - status.missing_files).each(&rmlink)
	end
      end
    end

    def disable(addons)
      map_override_lines do |lines|
        addons.each do |addon|  # disable each not yet disabled addon
          if not addon.disabled_by_line
            Vim.warn \
              "#{addon} can't be disabled (since it has no disabledby field)"
            next
          end
          unless lines.any? {|line| addon.is_disabled_by? line}
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
          lines.reject! {|line| addon.is_disabled_by? line}
        end
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

  end

end

