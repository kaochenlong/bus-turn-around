ActiveSupport.on_load(:action_view) do
  self.field_error_proc = ->(html_tag, _instance) { html_tag }
end
