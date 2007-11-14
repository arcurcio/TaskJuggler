#
# RichTextSyntaxRules.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

# This modules contains the syntax definition for the RichTextParser. The
# defined syntax aims to be compatible to the most commonly used markup
# elements of the MediaWiki system. See
# http://en.wikipedia.org/wiki/Wikipedia:Cheatsheet for details.
#
# Linebreaks are treated just like spaces as word separators unless it is
# followed by another newline or any of the start-of-line special characters.
# These characters start sequences that mark headlines, bullet items and such.
# The special meaning only gets activated when used at the start of the line.
#
# The parser traverses the input text and creates a tree of RichTextElement
# objects. This is the intermediate representation that can be converted to
# the final output format.
module RichTextSyntaxRules

  # This is the entry node.
  def rule_richtext
    pattern(%w( !sections !blankLines ), lambda {
      el = RichTextElement.new(:richtext, @val[0])
    })
  end

  # The following syntax elements are all block elements that can span
  # multiple lines.
  def rule_sections
    optional
    repeatable
    pattern(%w( !headlines !blankLines ), lambda {
      @val[0]
    })
    pattern(%w( !paragraph ), lambda {
      @val[0]
    })
    pattern(%w( $PRE ), lambda {
      RichTextElement.new(:pre, @val[0])
    })
    pattern(%w( !bulletList1 ), lambda {
      RichTextElement.new(:bulletlist1, @val[0])
    })
    pattern(%w( !numberList1 ), lambda {
      @numberListCounter = [ 0, 0, 0 ]
      RichTextElement.new(:numberlist1, @val[0])
    })
  end

  def rule_headlines
    pattern(%w( !title1 ), lambda {
      @val[0]
    })
    pattern(%w( !title2 ), lambda {
      @val[0]
    })
    pattern(%w( !title3 ), lambda {
      @val[0]
    })
  end

  def rule_title1
    pattern(%w( $TITLE1 !text $TITLE1END ), lambda {
      el = RichTextElement.new(:title1, @val[1])
      @sectionCounter[0] += 1
      el.data = @sectionCounter.dup
      el
    })
  end

  def rule_title2
    pattern(%w( $TITLE2 !text $TITLE2END ), lambda {
      el = RichTextElement.new(:title2, @val[1])
      @sectionCounter[1] += 1
      el.data = @sectionCounter.dup
      el
    })
  end

  def rule_title3
    pattern(%w( $TITLE3 !text $TITLE3END ), lambda {
      el = RichTextElement.new(:title3, @val[1])
      @sectionCounter[2] += 1
      el.data = @sectionCounter.dup
      el
    })
  end

  def rule_bulletList1
    optional
    repeatable
    pattern(%w( $BULLET1 !text $LINEBREAK), lambda {
      RichTextElement.new(:bulletitem1, @val[1])
    })
    pattern(%w( !bulletList2 ), lambda {
      RichTextElement.new(:bulletlist2, @val[0])
    })
  end

  def rule_bulletList2
    repeatable
    pattern(%w( $BULLET2 !text $LINEBREAK), lambda {
      RichTextElement.new(:bulletitem2, @val[1])
    })
    pattern(%w( !bulletList3 ), lambda {
      RichTextElement.new(:bulletlist3, @val[0])
    })
  end

  def rule_bulletList3
    repeatable
    pattern(%w( $BULLET3 !text $LINEBREAK), lambda {
      RichTextElement.new(:bulletitem3, @val[1])
    })
  end

  def rule_numberList1
    optional
    repeatable
    pattern(%w( $NUMBER1 !text $LINEBREAK), lambda {
      el = RichTextElement.new(:numberitem1, @val[1])
      @numberListCounter[0] += 1
      el.data = @numberListCounter.dup
      el
    })
    pattern(%w( !numberList2 ), lambda {
      @numberListCounter[1, 2] = [ 0, 0 ]
      RichTextElement.new(:numberlist2, @val[0])
    })
  end

  def rule_numberList2
    repeatable
    pattern(%w( $NUMBER2 !text $LINEBREAK), lambda {
      el = RichTextElement.new(:numberitem2, @val[1])
      @numberListCounter[1] += 1
      el.data = @numberListCounter.dup
      el
    })
    pattern(%w( !numberList3 ), lambda {
      @numberListCounter[2] = 0
      RichTextElement.new(:numberlist3, @val[0])
    })
  end

  def rule_numberList3
    repeatable
    pattern(%w( $NUMBER3 !text $LINEBREAK), lambda {
      el = RichTextElement.new(:numberitem3, @val[1])
      @numberListCounter[2] += 1
      el.data = @numberListCounter.dup
      el
    })
  end

  def rule_paragraph
    pattern(%w( !text $LINEBREAK ), lambda {
      RichTextElement.new(:paragraph, @val[0])
    })
  end

  def rule_text
    repeatable
    pattern(%w( !plainTextWithLinks ), lambda {
      @val[0]
    })
    pattern(%w( $ITALIC !plainTextWithLinks $ITALIC ), lambda {
      RichTextElement.new(:italic, @val[1])
    })
    pattern(%w( $BOLD !plainTextWithLinks $BOLD ), lambda {
      RichTextElement.new(:bold, @val[1])
    })
    pattern(%w( $CODE !plainTextWithLinks $CODE ), lambda {
      RichTextElement.new(:code, @val[1])
    })
    pattern(%w( $BOLDITALIC !plainTextWithLinks $BOLDITALIC ), lambda {
      RichTextElement.new(:bold, RichTextElement.new(:italic, @val[1]))
    })
  end

  def rule_plainTextWithLinks
    repeatable
    pattern(%w( $WORD ), lambda {
      RichTextElement.new(:text, @val[0])
    })
    pattern(%w( $REF $WORD !plainText $REFEND ), lambda {
      el = RichTextElement.new(:ref,
                               RichTextElement.new(:text, @val[2].empty? ?
                                                   @val[1] :
                                                   @val[2].join(' ')))
      el.data = @val[1]
      el
    })
    pattern(%w( $HREF $WORD !plainText $HREFEND ), lambda {
      el = RichTextElement.new(:href,
                               RichTextElement.new(:text, @val[2].empty? ?
                                                   @val[1] :
                                                   @val[2].join(' ')))
      el.data = @val[1]
      el
    })
  end

  def rule_plainText
    repeatable
    optional
    pattern(%w( $WORD ), lambda {
      RichTextElement.new(:text, @val[0])
    })
  end

  def rule_blankLines
    optional
    repeatable
    pattern(%w( $LINEBREAK ))
  end

end
