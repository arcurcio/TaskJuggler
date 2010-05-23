#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = test_Scheduler.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if __FILE__ == $0
$:.unshift File.dirname(__FILE__)

require 'test/unit'
require 'Tj3Config'
require 'TaskJuggler'
require 'MessageChecker'

class TestReportGenerator < Test::Unit::TestCase

  include MessageChecker

  def setup
    @tmpDir = 'tmp'
    Dir.delete(@tmpDir) if Dir.exists?(@tmpDir)
    Dir.mkdir(@tmpDir)
    AppConfig.appName = 'taskjuggler3'
    ENV['TASKJUGGLER_DATA_PATH'] = './:../'
  end

  def teardown
    Dir.delete(@tmpDir)
  end

  def test_ReportGeneratorErrors
    path = File.dirname(__FILE__) + '/'
    Dir.glob(path + 'TestSuite/ReportGenerator/Errors/*.tjp').each do |f|
      ENV['TZ'] = 'Europe/Berlin'
      tj = TaskJuggler.new(false)
      assert(tj.parse([ f ]), "Parser failed for #{f}")
      assert(tj.schedule, "Scheduler failed for #{f}")
      tj.warnTsDeltas = true
      tj.generateReports(@tmpDir)
      checkMessages(tj, f)
    end
  end

  def test_ReportGeneratorCorrect
    path = File.dirname(__FILE__) + '/'
    Dir.glob(path + 'TestSuite/ReportGenerator/Correct/*.tjp').each do |f|
      ENV['TZ'] = 'Europe/Berlin'
      tj = TaskJuggler.new(true)
      assert(tj.parse([ f ]), "Parser failed for ${f}")
      assert(tj.schedule, "Scheduler failed for #{f}")
      assert(tj.generateReports(@tmpDir), "Report generator failed for #{f}")
      assert(tj.messageHandler.messages.empty?, "Unexpected error in #{f}")
    end
  end

end
