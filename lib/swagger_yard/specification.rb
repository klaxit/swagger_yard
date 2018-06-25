module SwaggerYard
  class Specification
    attr_accessor :authorizations

    def initialize(controller_path = SwaggerYard.config.controller_path,
                   model_path = SwaggerYard.config.model_path)
      @model_paths = [*model_path].compact
      @controller_paths = [*controller_path].compact

      @resource_to_file_path = {}
      @authorizations = []
    end

    def models
      @models ||= parse_models
    end

    def controllers
      @controllers ||= parse_controllers
    end

    def to_h
      { "paths"               => path_objects,
        "definitions"         => model_objects,
        "tags"                => tag_objects,
        "securityDefinitions" => security_objects }
    end

    def path_objects
      controllers.map(&:apis_hash).reduce({}, :merge).tap do |paths|
        warn_duplicate_operations(paths)
      end
    end

    # Resources
    def tag_objects
      controllers.sort {|a,b| a.resource.upcase <=> b.resource.upcase}.map(&:to_tag)
    end

    def model_objects
      Hash[models.map {|m| [m.id, m.to_h]}]
    end

    def security_objects
      controllers # triggers controller parsing in case it did not happen before
      SwaggerYard.config.security_definitions.merge(
        Hash[authorizations.map {|auth| [auth.name, auth.to_h]}]
      )
    end

    private

    def parse_models
      @model_paths.map do |model_path|
        Dir[model_path.to_s].map do |file_path|
          SwaggerYard.yard_class_objects_from_file(file_path).map do |obj|
            Model.from_yard_object(obj)
          end
        end
      end.flatten.compact.select(&:valid?)
    end

    def parse_controllers
      @controller_paths.map do |controller_path|
        Dir[controller_path.to_s].map do |file_path|
          SwaggerYard.yard_class_objects_from_file(file_path).map do |obj|
            obj.tags.select {|t| t.tag_name == "authorization"}.each do |t|
              @authorizations << Authorization.from_yard_object(t)
            end
            ApiDeclaration.from_yard_object(obj)
          end
        end
      end.flatten.select(&:valid?)
    end

    def warn_duplicate_operations(paths)
      operation_ids = []
      paths.each do |path,ops|
        ops.each do |method,op|
          if operation_ids.include?(op['operationId'])
            SwaggerYard.log.warn("duplicate operation #{op['operationId']}")
            next
          end
          operation_ids << op['operationId']
        end
      end
    end
  end
end