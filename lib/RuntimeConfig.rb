#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = RuntimeConfig.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'yaml'

# The RuntimeConfig searches for a YAML config file in a list of directories.
# When a file is found it is read-in. The read-in config values are grouped in
# a tree of sections. The values of a section can then be used to overwrite
# the instance variable of a passed object.
class RuntimeConfig

  def initialize(appName, configFile = nil)
    @appName = appName
    @config = nil

    if configFile
      # Read user specified config file.
      if File.exist?(file)
        @config = YAML::load(File.open(configFile))
      else
        raise "Config file #{configFile} not found!"
      end
    else
      # Search config files in certain directories.
      @path = [ '.', ENV['HOME'], '/etc' ]

      @path.each do |path|
        # Try UNIX style hidden file first, then .rc.
        [ "#{path}/.#{appName}rc", "#{path}/#{appName}.rc" ].each do |file|
          if File.exist?(file)
            @config = YAML::load(File.read(file))
            break
          end
        end
        break if @config
      end
    end
  end

  def configure(object, section)
    sections = section.split('.')
    p = @config
    sections.each do |sec|
      return false if p.nil? || !p.include?(sec)
      p = p[sec]
    end

    object.instance_variables.each do |iv|
      ivName = iv[1..-1]
      object.instance_variable_set(iv, p[ivName]) if p.include?(ivName)
    end

    true
  end
end
