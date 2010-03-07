#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = tj3ts_summary.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This script is used to send out the time sheet templates to the employees.
# It should be run from a cron job once a week.

require 'Tj3AppBase'
require 'TimeSheetSummary'

# Name of the application
AppConfig.appName = 'tj3ts_summary'

class TaskJuggler

  class Tj3TsSummary < Tj3AppBase

    def initialize
      super

      # The default report period end is next Monday 0:00.
      @date = TjTime.now.nextDayOfWeek(1)
      @resourceList = []
      @receipients = []
    end

    def processArguments(argv)
      super do
        @opts.banner += <<'EOT'
This program can be used to send out a summary of all accepted time sheets a
list of email addresses. The directory structures for templates and submitted
time sheets must be present. The project data will be accesses via tj3client
from a running TaskJuggler server process.
EOT
        @opts.on('-r', '--resource <ID>', String,
                 format('Only generate summary for given resource')) do |arg|
          @resourceList << arg
        end
        @opts.on('-t', '--to <EMAIL>', String,
                 format('Send a summary report to this email address')) do |arg|
          @receipients << arg
        end
        optsEndDate
      end
    end

    def main
      super
      ts = TimeSheetSummary.new
      @rc.configure(ts, 'global')
      @rc.configure(ts, 'timesheets')
      @rc.configure(ts, 'timesheets.summary')
      ts.workingDir = @workingDir if @workingDir
      ts.dryRun = @dryRun
      ts.date = @date if @date
      ts.receipients += @receipients

      ts.sendSummary(@resourceList)
    end

  end

end

TaskJuggler::Tj3TsSummary.new.main()
