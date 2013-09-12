require 'alloy/ast/type_checker'
require 'alloy/dsl/model_api'
require 'alloy/dsl/sig_api'

require 'sdg_utils/caching/searchable_attr'
require 'sdg_utils/random'

require 'seculloy/dsl/trigger_helper'
require 'seculloy/dsl/guard_helper'
require 'seculloy/model/data'
require 'seculloy/model/operation'
require 'seculloy/model/invocation'

module Seculloy
  module Dsl

    module ModuleDslApi
      include Alloy::Dsl::SigDslApi
      include Seculloy::Dsl::TriggerHelper
      include Seculloy::Dsl::GuardHelper

      alias_method :assumption, :guard
      alias_method :invokes, :sends

      def creates(*data_classes)
        data_classes.each do |data_cls|
          meta.add_creates(data_cls)
        end
      end

      def operation(*args, &body)
        # evaluate ops lazily
        ans = Alloy::Dsl::SigBuilder.new(
          :superclass => Seculloy::Model::Operation,
          :scope_class => self
        ).sig(*args, &body)
        # TODO: check that all fields are of type Data
        ops = (Array === ans) ? ans : [ans]
        ops.each do |op|
          meta.add_operation op
          class_eval <<-RUBY, __FILE__, __LINE__+1
            def self.#{op.relative_name}(*args, &blk)
              #{relative_name}::#{op.relative_name}.some(*args, &blk)
            end
          RUBY
        end
      end

      # Extend the existing Alloy::Ast::SigMeta class with some extra
      # methods for fetching Seculloy specific stuff.
      def _define_meta
        meta = super
        meta.singleton_class.send :include, AlloySigMetaModuleExt
        meta
      end
    end

    module AlloySigMetaModuleExt
      include SDGUtils::Caching::SearchableAttr

      attr_hier_searchable :operation, :trigger, :guard

      def creates()             @creates ||= [] end
      def add_creates(data_cls)
        msg = "Use `add_creates' to add a *Data* instance"
        Alloy::Ast::TypeChecker.check_sig_class(data_cls, Seculloy::Model::Data)
        creates << data_cls
      end

      def trusted?()    !!@trusted end
      def set_trusted() @trusted = true end

      def many?()     !!@many end
      def set_many()  @many = true end

      def operation(name)          sig_cls.const_get name end

      def _hierarchy_up
        up=super && AlloySigMetaModuleExt === up
      end

    end
  end
end
