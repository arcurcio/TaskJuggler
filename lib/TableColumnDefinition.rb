#
# TableColumnDefinition.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


class TableColumnDefinition

  attr_reader :id
  attr_accessor :title, :scale, :content

  def initialize(id, title)
    @id = id
    @title = title
    @content = 'load'
    @scale = 'week'
  end

end

