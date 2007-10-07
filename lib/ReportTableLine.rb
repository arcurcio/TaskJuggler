#
# ReportTableLine.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'ReportTableCell'

class ReportTableLine

  attr_reader :table, :property, :scopeLine
  attr_accessor :indentation, :fontFactor, :no, :lineNo, :subLineNo

  def initialize(table, property, scopeLine)
    @table = table
    @property = property
    @scopeLine = scopeLine

    @table.addLine(self)
    @cells = []
    @indentation = 0
    @fontFactor = 1.0
    # Counter that counts primary and nested lines separately. It restarts
    # with 0 for each new nested line set. Scenario lines don't count.
    @no = nil
    # Counter that counts the primary lines. Scenario lines don't count.
    @lineNo = nil
    # Counter that counts all lines.
    @subLineNo = nil
  end

  def last(count = 0)
    # Return the last non-hidden cell of the line.
    (1 + count).upto(@cells.length) do |i|
      return @cells[-i] unless @cells[-i].hidden
    end
    nil
  end

  def setOut(out)
    @out = out
    @cells.each { |cell| cell.setOut(out) }
  end

  def addCell(cell)
    @cells << cell
  end

  def to_html
    tr = XMLElement.new('tr', 'class' => 'tabline1')
    @cells.each { |cell| tr << cell.to_html }
    tr
  end

end

