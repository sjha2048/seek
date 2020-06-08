module Seek
  module BreadCrumbs
    def self.included(base)
      base.before_action :add_breadcrumbs
    end

    def add_breadcrumbs
      add_breadcrumb('Home', root_path)

      add_parent_breadcrumbs # If this is a nested route, add breadcrumbs for the parent resource and its index

      add_self_breadcrumbs # If this is a "member" route, add breadcrumbs for resource we are looking at and its index

      add_action_breadcrumb # If this is an action on a resource (other than "show") add a breadcrumb for the action
    end

    private

    def add_parent_breadcrumbs
      if @parent_resource
        add_index_breadcrumb @parent_resource.class.name.underscore.pluralize, nil, path: polymorphic_path([@parent_resource, controller_name])
        add_resource_breadcrumb @parent_resource
      end
    end

    def add_self_breadcrumbs
      add_index_breadcrumb(controller_name)

      resource = instance_variable_get("@#{controller_name.singularize}")
      if resource && resource.respond_to?(:new_record?) && !resource.new_record?
        add_resource_breadcrumb(resource)
      end
    end

    def add_action_breadcrumb
      unless action_name == 'show'
        case action_name
        when 'new_object_based_on_existing_one'
          breadcrumb_name = "New #{controller_name.humanize.singularize.downcase} based on this one"
        when 'create_content_blob'
          breadcrumb_name = "New #{controller_name.humanize.singularize.downcase} details"
        when 'create'
          breadcrumb_name = "New"
        when 'index'
          breadcrumb_name = "#{t(controller_name.singularize, default: controller_name.singularize.humanize).pluralize} Index"
        else
          breadcrumb_name = action_name.capitalize.humanize
        end
        url = if resource.nil? && action_name == 'create'
                nil
              else
                request.path
              end
        add_breadcrumb breadcrumb_name, url
      end
    end


    def add_index_breadcrumb(controller_name, breadcrumb_name = nil, path: nil)
      unless breadcrumb_name
        breadcrumb_name = case controller_name
                          when 'studied_factors'
                            'Factors studied Index'
                          when 'admin'
                            'Administration'
                          when 'site_announcements'
                            'Announcements'
                          when 'suggested_assay_types'
                            'Assay types'
                          when 'suggested_technology_types'
                            'Technology types'
                          else
                            "#{t(controller_name.singularize, default: controller_name.singularize.humanize).pluralize} Index"
                          end
      end

      if %w[compounds suggested_assay_types suggested_technology_types site_announcements].include?(controller_name)
        controller_name = 'admin'
        breadcrumb_name = 'Administration'
      end
      path ||= polymorphic_path(controller_name)
      add_breadcrumb breadcrumb_name, path
    end

    def add_resource_breadcrumb(resource, breadcrumb_name = nil)
      breadcrumb_name ||= (resource.respond_to?(:title) ? resource.title : resource.id).to_s
      add_breadcrumb breadcrumb_name, polymorphic_path(resource)
    end

  end
end
