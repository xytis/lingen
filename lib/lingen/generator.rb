
class Lingen::Produce
  @@param_regex = /\([^\)]+?\)/
    def initialize(string)
      @output = string
    end

  def produce(params)
    result = String.new(@output)
    if (params) then
      result.gsub!(@@param_regex) do
        |s|
        keys = Regexp.new(params.keys.join('|'))
        working = s[1..-2].gsub(keys,params)
        '(' + working.split(',').map! { |x| eval(x).to_s }.join(',') + ')'
      end
    end
    result
  end
end

class Lingen::Module
  attr_reader :system

  def initialize(definition)
    @variables = definition[:variables].map!{ |v| Regexp.escape(v) } 
    @constants = definition[:constants].map!{ |v| Regexp.escape(v) }
    #Check if axiom is valid:
    params = '(\([^\)]+?\))?'
    helper = @variables.join(params+'|') + params+'|'+ @constants.join('|')
    parser = '(?<item>' + helper + ')'
    validator = '^(' + helper + ')+$'
    @parser = Regexp.new(parser)
    @validator = Regexp.new(validator)
    raise "Axiom contains unknown symbols" unless @validator.match(definition[:axiom])
    @axiom = definition[:axiom]
    @rules = []
    definition[:rules].each { |r| @rules.push(Rule.new(r, @validator)) }
    raise "No rules specified!" if @rules.empty?

    reset()
    #normalize probabilities
    groups = {}
    @rules.each do
      |r|
      key = (r.left or "") + '<' + r.seed + (r.params and r.params.size.to_s or "") + '>' + (r.right or "")
      if (groups[key]) then
        groups[key].push(r)
      else
        groups[key] = [r]
      end
    end
    groups.each do
      |k,v|
      probability = 0.0
      count = 0
      v.each do
        |r|
        probability += r.probability if r.probability
        count += 1 unless r.probability
      end 
      raise "Probability exceeds 1.0" if probability > 1.0
      if count > 0 then
        probability = 1.0 - probability
        probability /= count
      end
      v.each do
        |r|
        r.probability = probability unless r.probability
      end
    end
  end

  def reset()
    result = @system
    @system = @axiom
    return result
  end


  def populate()
    #do one iteration
    parsed = @system.split(@parser).select{ |s| not s.empty? }
    result = []
    (0..parsed.size-1).each do
      |i|
      result.push(parsed[i])
      matched_rules = []
      @rules.each do
        |r|
        left = parsed[i-1] if i > 0
        seed = parsed[i]
        right = parsed[i+1]
        if (r.match(left, seed, right)) then
          #result[i] = r.output(seed)
          matched_rules.push(r)
        end
      end
      #pick one rule
      random = rand()
      matched_rules.each do
        |r|
        random -= r.probability
        if (random < 0) then
          result[i] = r.output(parsed[i])
          break
        end
      end
    end
    @system = result.join
  end

end

class Lingen::Rule
  @@rule_pattern = /^(:?\s*(?<left>\w+)\s*<\s*)?(?<name>\w+)(:?\((?<params>(?<=\().*?(?=\)))\))?(:?\s*>\s*(?<right>\w+))?(:?\s*\|?(?<probability>(?<=\|).+?(?=\|))?\|?\s*->\s*)(?<output>.*$)/

    attr_accessor :probability
  attr_reader :seed, :left, :right, :params

  def initialize(pattern, validator)
    match = @@rule_pattern.match(pattern)
    raise "Rule key resolution failed in #{pattern}" unless match and match[:name]

    opt_par = '(\([^\)]+?\))?'
    regex = "^"
    if match[:left] then
      @left_regex = Regexp.new('^' + match[:left] + opt_par + '$') #expect a left before current.
      @left = match[:left]
      raise "Left context is invalid in #{pattern}" unless validator.match(@left)
    end
    @seed_regex = '^' + match[:name]
    @seed = match[:name]
    raise "Rule seed is invalid in #{pattern}" unless validator.match(@seed)
    if match[:params] then
      @params = match[:params].split(',',-1)
      #print " extracted parameter names: ", @params, "\n"
      @seed_regex += "\\((?<params>([^,]+?,?){#{@params.size}})\\)" #expect a number of parameters.
    end
    @seed_regex = Regexp.new(@seed_regex + '$')
    if match[:right] then
      @right_regex = Regexp.new('^' + match[:right] + opt_par + '$') #expect a right after current.
      @right = match[:right]
      raise "Right context is invalid in #{pattern}" unless validator.match(@right)
    end

    @probability = match[:probability].to_f if match[:probability]

    @output = Lingen::Produce.new(match[:output])
    #p regex
  end

  def match(left, seed, right)
    if (@seed_regex.match(seed)) then
      context = true
      if (@left and not @left_regex.match(left)) then
        context = false
      end
      if (@right and not @right_regex.match(right)) then
        context = false
      end
      context
    else
      false
    end
  end

  def output(seed)
    if (@params) then
      params = @seed_regex.match(seed)[:params].split(',')
      params = Hash[@params.zip(params)]
    end
    @output.produce(params)
  end
end
