#!/usr/bin/env ruby -w

# brew-import(1) - Import existing Homebrew installations
#
# ## SYNOPSYS
#
# `brew import` [<file>]
#
# ## Description
#
# `brew import` imports formulae that have been exported from another
# installation. Formaulae that are already installed are reinstalled with the
# flags given in the import data.
#
# If no file is given, or the file is '-', the data will be read from stdin.

require "cmd/tap"
require "utils/json"
require "formula"
require "formula_installer"
require "keg"
require "options"

module BrewExport
  class <<self
    def bin
      "brew import"
    end

    def usage(code = 0)
      puts "usage: #{bin} [options] [<file>]"
      puts ""
      puts "Imports formulae from given export data from another homebrew installation."
      puts "If no file is given or the file is '-', input will be read from stdin."
      exit code unless code == false
      true
    end

    def import
      usage if ARGV.include? '--help' or ARGV.include? '-h'

      case ARGV.named.length
      when 0
        file = nil
      when 1
        if ARGV.named.first == '-'
          file = nil
        else
          file = Pathname.new(ARGV.named.first)
        end
      else
        usage 1
      end

      # get the data

      data = if file.nil?
        Utils::JSON.load(STDIN.read)
      else
        Utils::JSON.load(file.read)
      end

      formulae = []

      data.each do |f, options|
        parts = /([^\/]+)\/(?:homebrew-)?([^\/]+)\/.+/.match f
        if parts
          tap = [parts[1], parts[2]]
          f = f.sub '/homebrew-', '/'
        else
          tap = nil
        end
        formulae << [ tap, f, options ]
      end

      # (re)install all formulae

      formulae.each { |f| install_formula(*f) }
    end

    def install_formula tap, f, options
      if not tap.nil?
          Homebrew.install_tap *tap
      end

      f = Formula[f]
      tab = Tab.for_formula f

      if f.installed?
        notice = "Reinstalling #{f.name}"
      else
        notice = "Installing #{f.name}"
      end
      notice += " with #{options['options'] * ", "}" unless options['options'].empty?
      oh1 notice

      if f.opt_prefix.directory?
        keg = Keg.new(f.opt_prefix.resolved_path)
        backup keg
      end

      f.print_tap_action

      fi = FormulaInstaller.new(f)
      fi.options             = Options.create options['options']
      fi.build_bottle        = ARGV.build_bottle? || options['build_bottle']
      fi.build_from_source   = ARGV.build_from_source?
      fi.force_bottle        = ARGV.force_bottle?
      fi.verbose             = ARGV.verbose?
      fi.debug               = ARGV.debug?
      fi.prelude
      fi.install
      fi.caveats
      fi.finish
    rescue FormulaInstallationAlreadyAttemptedError
      # next
    rescue Exception
      ignore_interrupts { restore_backup(keg, f) }
      raise
    else
      backup_path(keg).rmtree if backup_path(keg).exist?
    end

    def backup keg
      keg.unlink
      keg.rename backup_path(keg)
    end

    def restore_backup keg, formula
      path = backup_path(keg)
      if path.directory?
        path.rename keg
        keg.link unless formula.keg_only?
      end
    end

    def backup_path path
      Pathname.new "#{path}.reinstall"
    end
  end
end

BrewExport.import
