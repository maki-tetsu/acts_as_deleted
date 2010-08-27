module MakiTetsu #:nodoc:
  module Acts #:nodoc:
    module Deleted
      def self.included(base) #:nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_deleted(options = {})
          unless acts_as_deleted? # don't let AR call this twice
            cattr_accessor :deleted_attribute
            self.deleted_attribute = options[:with] || :deleted
            alias_method :destroy_without_callbacks!, :destroy_without_callbacks
            class << self
              VALID_FIND_OPTIONS << :with_deleted unless VALID_FIND_OPTIONS.include?(:with_deleted)
              VALID_FIND_OPTIONS << :for_deleted unless VALID_FIND_OPTIONS.include?(:for_deleted)
              alias_method :find_every_with_deleted, :find_every
              alias_method :calculate_with_deleted,  :calculate
              alias_method :delete_all!,             :delete_all
            end
          end
          include InstanceMethods
        end
  
        def acts_as_deleted?
          self.included_modules.include?(InstanceMethods)
        end
      end

      module InstanceMethods #:nodoc:
        def self.included(base) #:nodoc:
          base.extend ClassMethods
        end
  
        module ClassMethods
          def find_with_deleted(*args)
            options = args.extract_options!
            validate_find_options(options)
            set_readonly_option!(options)
            options[:with_deleted] = true # yuck!
  
            case args.first
            when :first then find_initial(options)
            when :all   then find_every(options)
            else             find_from_ids(args, options)
            end
          end
  
          def count_with_deleted(*args)
            calculate_with_deleted(:count, *construct_count_options_from_args(*args))
          end
  
          def find_for_deleted(*args)
            options = args.extract_options!
            validate_find_options(options)
            set_readonly_option!(options)
            options[:for_deleted] = true
  
            case args.first
            when :first then find_initial(options)
            when :all   then find_every(options)
            else             find_from_ids(args, options)
            end
          end
  
          def count_for_deleted(*args)
            calculate_for_deleted(:count, *construct_count_options_from_args(*args))
          end
  
          def count(*args)
            args[0] && args[0].kind_of?(Hash) && args[0].delete(:for_deleted) ?
              count_for_deleted(*args) :
              with_deleted_scope { count_with_deleted(*args) }
          end
  
          def calculate(*args)
            with_deleted_scope { calculate_with_deleted(*args) }
          end
  
          def calculate_for_deleted(*args)
            for_deleted_scope { calculate_with_deleted(*args) }
          end
  
          def delete_all(conditions = nil)
            self.update_all ["#{self.deleted_attribute} = ?", true], conditions
          end
  
          protected
            def with_deleted_scope(&block)
              with_scope({:find => { :conditions => ["#{table_name}.#{deleted_attribute} = ?", false] } }, :merge, &block)
            end
  
            def for_deleted_scope(&block)
              with_scope({:find => { :conditions => ["#{table_name}.#{deleted_attribute} = ?", true] } }, :merge, &block)
            end
  
          private
            # all find calls lead hear
            def find_every(options)
              options.delete(:with_deleted) ?
                find_every_with_deleted(options) :
                  (options.delete(:for_deleted) ?
                     for_deleted_scope { find_every_with_deleted(options) } :
                     with_deleted_scope { find_every_with_deleted(options) } )
            end
        end
  
        def destroy_without_callbacks
          unless new_record?
            self.class.update_all self.class.send(:sanitize_sql, ["#{self.class.deleted_attribute} = ?", true]), ["#{self.class.primary_key} = ?", id]
          end
          freeze
        end
  
        def destroy_with_callbacks!
          return false if callback(:before_destroy) == false
          result = destroy_without_callbacks!
          callback(:after_destroy)
          result
        end
  
        def destroy!
          transaction { destroy_with_callbacks! }
        end
      end
    end
  end
end
