#
# TextParser.rb - The TaskJuggler3 Project Management Software
#
# Copyright (c) 2006, 2007 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#

require 'TextParserPattern'
require 'TextParserRule'
require 'TextParserStackElement'
require 'TjException'

# The TextParser implements a regular LALR parser. But it uses a recursive
# rule traversor instead of the more commonly found state machine generated by
# yacc-like tools. Since stack depths is not really an issue with a Ruby
# implementation this approach has one big advantage. The parser can be
# modified during parsing. This allows support for languages that can extend
# themself. The TaskJuggler syntax is such an beast. Traditional yacc
# generated parsers would fail with such a syntax.
#
# This class is just a base class. A complete parser would derive from this
# class and implement the rule set and the functions _nextToken()_ and
# _returnToken()_. It also needs to set the array _variables_ to declare all
# variables ($SOMENAME) that the scanner may deliver.
#
# To describe the syntax the functions TextParser#pattern, TextParser#optional
# and TextParser#repeatable can be used. When the rule set is changed during
# parsing, TextParser#updateParserTables must be called to make the changes
# effective. The parser can also document the syntax automatically. To
# document a pattern, the functions TextParser#doc, TextParser#descr,
# TextParser#also and TextParser#arg can be used.
#
# To start parsing the input the function TextParser#parse needs to be called
# with the name of the start rule.
class TextParser

  # Utility class so that we can distinguish Array results from the Array
  # containing the results of a repeatable rule.
  class TextParserResultArray < Array

    def initialize
      super
    end

    # If there is a repeatable rule that contains another repeatable loop, the
    # result of the inner rule is an Array that gets put into another Array by
    # the outer rule. In this case, the inner Array can be merged with the
    # outer Array.
    def <<(arg)
      if arg.is_a?(TextParserResultArray)
        self.concat(arg)
      else
        super
      end
    end

  end

  attr_reader :rules

  # Create a new TextParser object.
  def initialize
    @rules = { }
    # Array to hold the token types that the scanner can return.
    @variables = []
    # The currently processed rule.
    @cr = nil
    # If set to a value larger than 0 debug output will be generated.
    @@debug = 0
  end

  # Call all methods that start with 'rule_' to initialize the rules.
  def initRules
    methods.each do |m|
      if m[0, 5] == 'rule_'
        # Create a new rule with the suffix of the function name as name.
        newRule(m[5..-1])
        # Call the function.
        send(m)
      end
    end
  end

  # Add a new rule to the rule set. _name_ must be a unique identifier. The
  # function also sets the class variable @cr to the new rule. Subsequent
  # calls to TextParser#pattern, TextParser#optional or
  # TextParser#repeatable will then implicitely operate on the most recently
  # added rule.
  def newRule(name)
    raise "Fatal Error: Rule #{name} already exists" if @rules.has_key?(name)

    @rules[name] = @cr = TextParserRule.new(name)
  end

  # Add a new pattern to the most recently added rule. _tokens_ is an array of
  # strings that specify the syntax elements of the pattern. Each token must
  # start with an character that identifies the type of the token. The
  # following types are supported.
  #
  # * ! a reference to another rule
  # * $ a variable token as delivered by the scanner
  # * _ a literal token.
  #
  # _func_ is a Proc object that is called whenever the parser has completed
  # the processing of this rule.
  def pattern(tokens, func = nil)
    @cr.addPattern(TextParserPattern.new(tokens, func))
  end

  # Identify the patterns of the most recently added rule as optional syntax
  # elements.
  def optional
    @cr.setOptional
  end

  # Identify the patterns of the most recently added rule as repeatable syntax
  # elements.
  def repeatable
    @cr.setRepeatable
  end

  # This function needs to be called whenever new rules or patterns have been
  # added and before the next call to TextParser#parse.
  def updateParserTables
    @rules.each_value { |rule| rule.transitions = {} }
    @rules.each_value do |rule|
      getTransitions(rule)
      checkRule(rule)
    end
  end

  # To parse the input this function needs to be called with the name of the
  # rule to start with. It returns the result of the processing function of
  # the top-level parser rule that was specified by _ruleName_.
  def parse(ruleName, enforceEndOfFile = true)
    @stack = []
    @@expectedTokens = []
    updateParserTables
    begin
      result = parseRule(@rules[ruleName])

      if enforceEndOfFile && (token = nextToken) != [ false, false ]
        error('eof_expected', 'End of file expected but found ' +
              "[ #{token[0]}, #{token[1]} ].")
      end
    rescue TjException
      return nil
    end

    result
  end

  # Return the SourceFileInfo of the TextScanner at the beginning of the
  # currently processed TextParserRule. Or return nil if we don't have a
  # current position.
  def sourceFileInfo
    return nil if @stack.empty?
    @stack.last.sourceFileInfo
  end

  def matchingRules(keyword)
    matches = []
    @rules.each do |name, rule|
      patIdx = rule.matchingPatternIndex('_' + keyword)
      matches << [ rule, patIdx ] if patIdx
    end
    matches
  end

  def error(id, text, property = nil)
    @scanner.error(id, text, property)
  end

private

  # getTransitions recursively determines all possible target tokens
  # that the _rule_ matches. A target token can either be a fixed
  # token (prefixed with _) or a variable token (prefixed with $). The
  # list of found target tokens is stored in the _transitions_ list of
  # the rule. For each rule pattern we store the transitions for this
  # pattern in a token -> rule hash.
  def getTransitions(rule)
    transitions = []
    # If we have processed this rule before we can just return a copy
    # of the transitions of this rule. This avoids endless recursions.
    return rule.transitions.clone unless rule.transitions.empty?

    rule.patterns.each do |pat|
      next if pat.empty?
      token = pat[0].slice(1, pat[0].length - 1)
      if pat[0][0] == ?!
        result = { }
        unless @rules.has_key?(token)
          raise "Fatal Error: Unknown reference to #{token} in pattern " +
                "#{pat} + of rule #{rule.name}"
        end
        res = getTransitions(@rules[token])
        # Combine the hashes for each pattern into a single hash
        res.each do |pat|
          pat.each { |tok, r| result[tok] = r }
        end
      elsif pat[0][0] == ?_ || pat[0][0] == ?$
        result = { pat[0] => rule }
      else
        raise "Fatel Error: Illegal token type specifier used for token" +
	      ": #{token}"
      end
      # Make sure that we only have one possible transition for each
      # target.
      result.each do |key, value|
        transitions.each do |trans|
          if trans.has_key?(key)
	    raise "Fatal Error: Rule #{rule.name} has ambigeous transitions " +
	          "for target #{key}"
	  end
	end
      end
      transitions << result
    end
    # Store the list of found transitions with the rule.
    rule.transitions = transitions.clone
  end

  def checkRule(rule)
    if rule.patterns.empty?
      raise "Rule #{rule.name} must have at least one pattern"
    end

    rule.patterns.each do |pat|
      pat.each do |tok|
        type = tok[0]
        token = tok.slice(1, tok.length - 1)
        if type == ?$
          if @variables.index(token).nil?
            raise "Fatal Error: Illegal variable type #{token} used for " +
                  "rule #{rule.name} in pattern '#{pat}'"
          end
        elsif type == ?!
          if @rules[token].nil?
            raise "Fatal Error: Reference to unknown rule #{token} in " +
                  "pattern '#{pat}' of rule #{rule.name}"
          end
        end
      end
    end
  end

  # This function processes the input starting with the syntax description of
  # _rule_. It recursively calls this function whenever the syntax description
  # contains the reference to another rule.
  def parseRule(rule)
    $stderr.puts "Parsing with rule #{rule.name}" if @@debug >= 10
    result = rule.repeatable ? TextParserResultArray.new : nil
    # Rules can be marked 'repeatable'. This flag will be set to true after
    # the first iternation has been completed.
    repeatMode = false
    loop do
      # At the beginning of a rule we need a token from the input to determine
      # which pattern of the rule needs to be processed.
      begin
        token = nextToken
        $stderr.puts "  Token: #{token[0]}/#{token[1]}" if @@debug >= 20
      rescue TjException
        error('parse_rule1', $!.message)
      end

      # The scanner cannot differentiate between keywords and identifiers. So
      # whenever an identifier is returned we have to see if we have a
      # matching keyword first. If none is found, then look for normal
      # identifiers.
      if token[0] == 'ID'
        if (patIdx = rule.matchingPatternIndex('_' + token[1])).nil?
          patIdx = rule.matchingPatternIndex("$ID")
        end
      elsif token[0] == 'LITERAL'
        patIdx = rule.matchingPatternIndex('_' + token[1])
      elsif token[0] == false
        patIdx = nil
      else
        patIdx = rule.matchingPatternIndex('$' + token[0])
      end

      # If no matching pattern is found for the token we have to check if the
      # rule is optional or we are in repeat mode. If this is the case, return
      # the token back to the scanner. Otherwise we have found a token we
      # cannot handle at this point.
      if patIdx.nil?
        # Append the list of expected tokens to the @@expectedToken array.
        # This may be used in a later rule to provide more details when an
        # error occured.
        rule.transitions.each do |transition|
          keys = transition.keys
          keys.collect! { |key| key.slice(1, key.length - 1) }
          @@expectedTokens += keys
          @@expectedTokens.sort!
        end

        unless rule.optional || repeatMode
          error('unexpctd_token',
                (token[0] != false ?
                 "Unexpected token '#{token[1]}' of type '#{token[0]}'. " :
                 "Unexpected end of file in #{@scanner.fileName}. ") +
                (@@expectedTokens.length > 1 ?
                 "Expecting one of #{@@expectedTokens.join(', ')}" :
                 "Expecting #{@@expectedTokens[0]}"))
        end
        returnToken(token)
        if @@debug >= 10
          $stderr.puts "Finished parsing with rule #{rule.name} (*)"
        end
        return result
      end

      pattern = rule.pattern(patIdx)
      @stack << TextParserStackElement.new(rule, pattern.function,
                                           @scanner.sourceFileInfo)

      pattern.each do |element|
        # Separate the type and token text for pattern element.
        elType = element[0]
        elToken = element.slice(1, element.length - 1)
        if elType == ?!
          # The element is a reference to another rule. Return the token if we
          # still have one and continue with the referenced rule.
          unless token.nil?
            returnToken(token)
            token = nil
          end
          @stack.last.store(parseRule(@rules[elToken]))
        else
          # In case the element is a keyword or variable we have to get a new
          # token if we don't have one anymore.
          if token.nil?
            begin
              if (token = nextToken) == [ false, false ]
                error('unexpctd_eof', "Unexpected end of file")
              end
            rescue TjException
              error('parse_rule2', $!)
            end
          end

          if elType == ?_
            # If the element requires a keyword the token must match this
            # keyword.
            if elToken != token[1]
              text = "#{elToken} expected but found " +
                     "[#{token[0]}, '#{token[1]}']"
              unless @@expectedTokens.empty?
                text = "#{@@expectedTokens.join(', ')} or " + text
              end
              error('spec_keywork_expctd', text)
            end
            @stack.last.store(elToken)
          else
            # The token must match the expected variable type.
            if token[0] != elToken
              text = "#{elToken} expected but found " +
                     "[#{token[0]}, '#{token[1]}']"
              unless @@expectedTokens.empty?
                text = "#{@@expectedTokens.join(', ')} or " + text
              end
              error('spec_token_expctd', text)
            end
            # If the element is a variable store the value of the token.
            @stack.last.store(token[1])
          end
          # The token has been consumed. Reset the variable.
          token = nil
          @@expectedTokens = []
        end
      end

      # Once the complete pattern has been processed we call the processing
      # function for this pattern to operate on the value array. Then pop the
      # entry for this rule from the stack.
      @val = @stack.last.val
      res = nil
      res = @stack.last.function.call unless @stack.last.function.nil?
      @stack.pop

      # If the rule is not repeatable we can store the result and break the
      # outer loop to exit the function.
      unless rule.repeatable
        result = res
        break
      end

      # Otherwise we append the result to the result array and turn repeat
      # mode on.
      result << res
      repeatMode = true
    end

    $stderr.puts "Finished parsing with rule #{rule.name}" if @@debug >= 10
    return result
  end

end

