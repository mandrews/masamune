require 'active_support'
require 'active_support/core_ext/numeric/time'

class Masamune::DataPlan
  include Masamune::Accumulate

  def initialize
    @target_rules = Hash.new
    @source_rules = Hash.new
    @command_rules = Hash.new
    @targets = Hash.new { |set,rule| set[rule] = Masamune::DataPlanSet.new(@target_rules[rule]) }
    @sources = Hash.new { |set,rule| set[rule] = Masamune::DataPlanSet.new(@source_rules[rule]) }
    @set_cache = Hash.new { |cache,level| cache[level] = Hash.new }
  end

  def add_target_rule(rule, target, target_options = {})
    @target_rules[rule] = Masamune::DataPlanRule.new(self, rule, :target, target, target_options)
  end

  def add_source_rule(rule, source, source_options = {})
    @source_rules[rule] = Masamune::DataPlanRule.new(self, rule, :source, source, source_options)
  end

  def add_command_rule(rule, command)
    @command_rules[rule] = command
  end

  # TODO use constructed reference instead
  def rule_for_target(target)
    matches = @target_rules.select { |rule, matcher| matcher.matches?(target) }
    Masamune.logger.debug("No rule matches target #{target}") and return Masamune::DataPlanRule::TERMINAL if matches.empty?
    Masamune.logger.error("Multiple rules match target #{target}") if matches.length > 1
    matches.map(&:first).first
  end

  # TODO convert to DataPlanSet
  def targets_for_date_range(rule, start, stop, &block)
    target_template = @target_rules[rule]
    target_template.generate(start.to_time.utc, stop.to_time.utc) do |target_instance|
      yield target_instance
    end
  end
  method_accumulate :targets_for_date_range

  def targets_for_source(rule, source)
    source_template = @source_rules[rule]
    target_template = @target_rules[rule]
    source_instance = source.is_a?(Masamune::DataPlanElem) ? source : source_template.bind_path(source)

    @set_cache[:targets_for_source][rule + ':' + source_instance.path] ||= begin
      Masamune::DataPlanSet.new(target_template).tap do |set|
        source_template.generate_via_unify_path(source_instance.path, target_template) do |target|
          set.add target
        end
      end
    end
  end

  def sources_for_target(rule, target)
    source_template = @source_rules[rule]
    target_template = @target_rules[rule]
    target_instance = target.is_a?(Masamune::DataPlanElem) ? target : target_template.bind_path(target)

    @set_cache[:sources_for_target][rule + ':' + target_instance.path] ||= begin
      Masamune::DataPlanSet.new(source_template).tap do |set|
        target_template.generate_via_unify_path(target_instance.path, source_template) do |source|
          set.add source
        end
      end
    end
  end

  def targets(rule)
    @set_cache[:targets_for_rule][rule] ||= begin
      result = @sources[rule].map { |source| targets_for_source(rule, source) }.reduce(&:union)
      @targets[rule].union(result)
   end
  end

  def sources(rule)
    @set_cache[:sources_for_rule][rule] ||= begin
      result = @targets[rule].map { |target| sources_for_target(rule, target) }.reduce(&:union)
      @sources[rule].union(result).adjacent
    end
  end

  def prepare(rule, options = {})
    @targets[rule].merge options.fetch(:targets, [])
    @sources[rule].merge options.fetch(:sources, [])
  end

  def execute(rule, options = {})
    return if targets(rule).missing.empty?
    sources(rule).missing.group_by { |source| rule_for_target(source.path) }.each do |derived_rule, sources|
      if derived_rule != Masamune::DataPlanRule::TERMINAL
        prepare(derived_rule, targets: sources.map(&:path))
        execute(derived_rule, options)
      end
    end

    Masamune.with_exclusive_lock(rule) do
      @command_rules[rule].call(self, rule, options)
    end

    @set_cache.clear
  end
end
