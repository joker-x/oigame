Authorization.default_role = :anonymous

authorization do
  role :anonymous do
    has_permission_on [:campaigns], :to => [:index, :widget ,:widget_iframe, :message, :petition, :validate, :integrate, :validated, :feed, :archived, :search]
    has_permission_on [:campaigns], :to => [:show] do
      if_attribute :moderated => is { false }
    end
    has_permission_on [:donate], :to => [:index]
    has_permission_on [:pages], :to => [:index, :help, :tutorial, :privacy_policy, :contact, :contact_received]
    has_permission_on [:sub_oigames], :to => [:widget, :widget_iframe, :integrate]
  end
  
  role :user do
    includes :anonymous
    has_permission_on [:campaigns], :to => [:new, :create]
    has_permission_on [:campaigns], :to => [:show] do
      if_attribute :user => is { user } 
    end
    has_permission_on [:campaigns], :to => [:edit] do
      if_attribute :user => is { user }
    end
  end

  role :editor do
    includes :user
  end

  role :admin do
    includes :editor
  end
end
