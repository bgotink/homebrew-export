#!/usr/bin/env ruby -w

# brew-export(1) - Export existing Homebrew installations
#
# ## SYNOPSYS
#
# `brew export`
# `brew export` <formula> [<formula> ...]
#
# ## Description
#
# `brew export` exports the formulae that have been installed in the homebrew
# installation. If any formulae are given, only these formulae will be exported.

require 'formula'
require 'tab'
require 'utils/json'

module BrewExport
  class << self
    def bin
      "brew export"
    end

    def usage(code = 0)
      puts "usage: #{bin} [<formula> ...]"
      puts ""
      puts "Exports formulae from the homebrew installation."
      puts "If no formulae are given, all installed formulae are exported."
      exit code unless code == false
      true
    end

    def formulae
      if ARGV.named.length == 0
        Formula.installed
      else
        ARGV.formulae
      end
    end

    def export
      return usage if ARGV.include? '--help' or ARGV.include? '-h' or ARGV.include? 'help'

      export_info = Hash.new

      formulae.each do |f|
        export = export_formula(f)

        if f.tap?
          export_info["#{f.tap}/#{f.name}"] = export
        else
          export_info[f.name] = export
        end
      end

      puts Utils::JSON.dump(export_info)
    end

    def export_formula formula
      tab = Tab.for_formula formula
      result = Hash.new

      options = tab.used_options | formula.build.used_options
      result['options'] = options.as_flags

      result['build_bottle'] = tab.build_bottle?

      result
    end
  end
end

BrewExport.export
