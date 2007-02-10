# vim-addons: command line manager of Vim addons
#
# Copyright (C) 2007 Stefano Zacchiroli
#
# This program is free software, you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 2 as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# $Id: common.rb 866 2007-01-24 21:27:58Z zack $

require 'vim/constants'

module Vim

  def Vim.override_file(dir)
    File.join dir, OVERRIDE_FILE
  end


  @verbosity = 0

  class << self

    def increase_verbosity
      @verbosity += 1
    end

    def verbose?
      @verbosity >= 1
    end

    def warn(s)
      puts "Warning: #{s}"
    end

    def info(s)
      puts "Info: #{s}"
    end

    def system(cmd)
      info "executing '#{cmd}'" if verbose?
      Kernel::system cmd
    end
  end


end
