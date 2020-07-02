class CustomMetadataAttribute < ApplicationRecord
  belongs_to :sample_attribute_type
  belongs_to :custom_metadata_type

  def validate_value?(value)
    return false if required? && value.blank?
    (value.blank? && !required?) || sample_attribute_type.validate_value?(value, required: required?)
  end

  def accessor_name
    title
  end

  def resolve(value)
    resolution = if sample_attribute_type.resolution.present? && sample_attribute_type.regexp.present?
                   value.sub(Regexp.new(sample_attribute_type.regexp), sample_attribute_type.resolution)
                 end
    resolution
  end

  # to behave like a sample attribute, but is never a title
  def is_title
    false
  end

  # The method name used to get this attribute via a method call
  def method_name
    Seek::JSONMetadata::METHOD_PREFIX + accessor_name
  end

  def pre_process_value(value)
    sample_attribute_type.pre_process_value(value,{})
  end

end
